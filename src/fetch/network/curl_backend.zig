//! Libcurl Network Backend - WHATWG Fetch Implementation
//!
//! Production network backend using statically-compiled libcurl.
//! Implements NetworkBackend interface for HTTP/HTTPS requests.
//!
//! Spec: https://fetch.spec.whatwg.org/#http-network-fetch
//!
//! Features:
//! - HTTP/1.0, HTTP/1.1, HTTP/2 support
//! - TLS with mbedTLS (certificate validation)
//! - Proxy support with authentication
//! - Connection and request timeouts
//! - Response body and header collection
//! - Timing information for Resource Timing API
//! - Abort support via callback

const std = @import("std");
const Allocator = std.mem.Allocator;
const backend = @import("backend.zig");
const NetworkBackend = backend.NetworkBackend;
const NetworkRequest = backend.NetworkRequest;
const NetworkResponse = backend.NetworkResponse;
const NetworkError = backend.NetworkError;
const HttpVersion = backend.HttpVersion;
const curl = @import("curl_ffi.zig");
const curl_error = @import("curl_error.zig");

// =============================================================================
// Global State Management
// =============================================================================

/// Global initialization state (reference counted, thread-safe)
var global_init_count: usize = 0;
var global_init_mutex: std.Thread.Mutex = .{};

/// Initialize libcurl globally.
/// Thread-safe and reference counted - can be called multiple times.
/// Must call globalCleanup() the same number of times.
pub fn globalInit() !void {
    global_init_mutex.lock();
    defer global_init_mutex.unlock();

    if (global_init_count == 0) {
        const result = curl.global_init(curl.CURL_GLOBAL_DEFAULT);
        if (result != curl.CURLE_OK) {
            return error.CurlGlobalInitFailed;
        }
    }
    global_init_count += 1;
}

/// Decrement global init reference count.
/// When count reaches zero, libcurl global cleanup is performed.
pub fn globalCleanup() void {
    global_init_mutex.lock();
    defer global_init_mutex.unlock();

    if (global_init_count > 0) {
        global_init_count -= 1;
        if (global_init_count == 0) {
            curl.global_cleanup();
        }
    }
}

// =============================================================================
// LibcurlBackend Implementation
// =============================================================================

/// LibcurlBackend provides HTTP/HTTPS networking using libcurl.
///
/// Usage:
/// ```zig
/// try LibcurlBackend.globalInit();
/// defer LibcurlBackend.globalCleanup();
///
/// var backend = try LibcurlBackend.init(allocator);
/// defer backend.deinit();
///
/// const request = NetworkRequest{
///     .url = "https://example.com",
///     .method = "GET",
///     .headers = &.{},
///     .body = null,
/// };
///
/// var response = try backend.backend().send(allocator, &request);
/// defer response.deinit();
/// ```
pub const LibcurlBackend = struct {
    allocator: Allocator,

    /// Abort flag - set to true to cancel in-progress request
    aborted: std.atomic.Value(bool),

    const Self = @This();

    /// Initialize a new LibcurlBackend.
    /// Requires globalInit() to have been called first.
    pub fn init(allocator: Allocator) !*Self {
        const self = try allocator.create(Self);
        self.* = .{
            .allocator = allocator,
            .aborted = std.atomic.Value(bool).init(false),
        };
        return self;
    }

    /// Clean up backend resources.
    pub fn deinit(self: *Self) void {
        self.allocator.destroy(self);
    }

    /// Get as NetworkBackend interface.
    pub fn getBackend(self: *Self) NetworkBackend {
        return .{
            .ptr = self,
            .vtable = &vtable,
        };
    }

    // VTable implementation
    const vtable = NetworkBackend.VTable{
        .send = sendImpl,
        .abort = abortImpl,
        .supportsStreaming = supportsStreamingImpl,
        .getName = getNameImpl,
        .deinit = deinitImpl,
    };

    /// Callback context for curl write/header callbacks
    const CallbackContext = struct {
        allocator: Allocator,
        response_body: std.ArrayList(u8),
        response_headers: std.ArrayList(NetworkResponse.Header),
        raw_headers: std.ArrayList(u8),
        aborted: *std.atomic.Value(bool),

        fn init(allocator: Allocator, aborted: *std.atomic.Value(bool)) CallbackContext {
            return .{
                .allocator = allocator,
                .response_body = .empty,
                .response_headers = .empty,
                .raw_headers = .empty,
                .aborted = aborted,
            };
        }

        fn deinit(self: *CallbackContext) void {
            self.response_body.deinit(self.allocator);
            for (self.response_headers.items) |header| {
                self.allocator.free(header.name);
                self.allocator.free(header.value);
            }
            self.response_headers.deinit(self.allocator);
            self.raw_headers.deinit(self.allocator);
        }
    };

    fn sendImpl(ptr: *anyopaque, allocator: Allocator, request: *const NetworkRequest) NetworkError!NetworkResponse {
        const self: *Self = @ptrCast(@alignCast(ptr));

        // Reset abort flag
        self.aborted.store(false, .seq_cst);

        // Create curl easy handle
        const handle = curl.easy_init() orelse return NetworkError.OutOfMemory;
        defer curl.easy_cleanup(handle);

        // Initialize callback context
        var ctx = CallbackContext.init(allocator, &self.aborted);
        defer {
            // Only cleanup on error - on success, data is transferred to response
        }

        // Configure request
        configureRequest(handle, request, &ctx) catch {
            ctx.deinit();
            return NetworkError.OutOfMemory;
        };

        // Perform the request
        const result = curl.easy_perform(handle);

        // Check for abort
        if (self.aborted.load(.seq_cst)) {
            ctx.deinit();
            return NetworkError.Aborted;
        }

        // Check for errors
        if (result != curl.CURLE_OK) {
            ctx.deinit();
            return curl_error.mapCurlError(result);
        }

        // Parse headers from raw header data
        parseHeaders(&ctx) catch {
            ctx.deinit();
            return NetworkError.OutOfMemory;
        };

        // Extract response info
        var status_code: c_long = 0;
        _ = curl.easy_getinfo(handle, curl.CURLINFO_RESPONSE_CODE, &status_code);

        var http_version_raw: c_long = 0;
        _ = curl.easy_getinfo(handle, curl.CURLINFO_HTTP_VERSION, &http_version_raw);

        var total_time: f64 = 0;
        _ = curl.easy_getinfo(handle, curl.CURLINFO_TOTAL_TIME, &total_time);

        var starttransfer_time: f64 = 0;
        _ = curl.easy_getinfo(handle, curl.CURLINFO_STARTTRANSFER_TIME, &starttransfer_time);

        var redirect_count: c_long = 0;
        _ = curl.easy_getinfo(handle, curl.CURLINFO_REDIRECT_COUNT, &redirect_count);

        var primary_ip: [*c]const u8 = null;
        _ = curl.easy_getinfo(handle, curl.CURLINFO_PRIMARY_IP, &primary_ip);

        var primary_port: c_long = 0;
        _ = curl.easy_getinfo(handle, curl.CURLINFO_PRIMARY_PORT, &primary_port);

        var effective_url: [*c]const u8 = null;
        _ = curl.easy_getinfo(handle, curl.CURLINFO_EFFECTIVE_URL, &effective_url);

        // Resource Timing API: Extract detailed timing information
        var namelookup_time: f64 = 0;
        _ = curl.easy_getinfo(handle, curl.CURLINFO_NAMELOOKUP_TIME, &namelookup_time);

        var connect_time: f64 = 0;
        _ = curl.easy_getinfo(handle, curl.CURLINFO_CONNECT_TIME, &connect_time);

        var appconnect_time: f64 = 0;
        _ = curl.easy_getinfo(handle, curl.CURLINFO_APPCONNECT_TIME, &appconnect_time);

        var pretransfer_time: f64 = 0;
        _ = curl.easy_getinfo(handle, curl.CURLINFO_PRETRANSFER_TIME, &pretransfer_time);

        var redirect_time: f64 = 0;
        _ = curl.easy_getinfo(handle, curl.CURLINFO_REDIRECT_TIME, &redirect_time);

        // Check if connection was reused (num_connects == 0 means reused)
        var num_connects: c_long = 0;
        _ = curl.easy_getinfo(handle, curl.CURLINFO_NUM_CONNECTS, &num_connects);

        // Build response
        const http_version: HttpVersion = switch (http_version_raw) {
            curl.CURL_HTTP_VERSION_1_0 => .http_1_0,
            curl.CURL_HTTP_VERSION_1_1 => .http_1_1,
            curl.CURL_HTTP_VERSION_2_0 => .http_2,
            curl.CURL_HTTP_VERSION_3 => .http_3,
            else => .http_1_1,
        };

        // Transfer ownership of collected data
        const headers = ctx.response_headers.toOwnedSlice(allocator) catch {
            ctx.deinit();
            return NetworkError.OutOfMemory;
        };

        const body = if (ctx.response_body.items.len > 0)
            ctx.response_body.toOwnedSlice(allocator) catch {
                allocator.free(headers);
                ctx.deinit();
                return NetworkError.OutOfMemory;
            }
        else
            null;

        // Copy strings that need to outlive curl handle
        const final_url = if (effective_url != null and
            !std.mem.eql(u8, std.mem.span(effective_url.?), request.url))
            allocator.dupe(u8, std.mem.span(effective_url.?)) catch null
        else
            null;

        const remote_ip = if (primary_ip != null)
            allocator.dupe(u8, std.mem.span(primary_ip.?)) catch null
        else
            null;

        // Clean up remaining context resources
        ctx.raw_headers.deinit(allocator);

        return NetworkResponse{
            .allocator = allocator,
            .status = @intCast(status_code),
            .http_version = http_version,
            .headers = headers,
            .body = body,
            .final_url = final_url,
            .total_time_ms = @intFromFloat(total_time * 1000),
            .time_to_first_byte_ms = @intFromFloat(starttransfer_time * 1000),
            .redirect_count = @intCast(redirect_count),
            .remote_ip = remote_ip,
            .remote_port = if (primary_port > 0) @intCast(primary_port) else null,
            // Resource Timing API fields
            .dns_lookup_time_ms = @intFromFloat(namelookup_time * 1000),
            .connect_time_ms = @intFromFloat(connect_time * 1000),
            .app_connect_time_ms = @intFromFloat(appconnect_time * 1000),
            .pretransfer_time_ms = @intFromFloat(pretransfer_time * 1000),
            .redirect_time_ms = @intFromFloat(redirect_time * 1000),
            .connection_reused = (num_connects == 0),
        };
    }

    fn configureRequest(handle: *curl.CURL, request: *const NetworkRequest, ctx: *CallbackContext) !void {
        // URL (must be null-terminated)
        const url_z = try ctx.allocator.dupeZ(u8, request.url);
        defer ctx.allocator.free(url_z);
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
            // Format: "Name: Value" - allocate then convert to null-terminated
            const header_str = try std.fmt.allocPrint(ctx.allocator, "{s}: {s}", .{ header.name, header.value });
            defer ctx.allocator.free(header_str);
            // Create null-terminated copy for curl
            const header_z = try ctx.allocator.dupeZ(u8, header_str);
            defer ctx.allocator.free(header_z);
            header_list = curl.slist_append(header_list, header_z.ptr);
        }
        if (header_list != null) {
            _ = curl.easy_setopt(handle, curl.CURLOPT_HTTPHEADER, header_list);
        }
        // Note: header_list is freed by curl on cleanup

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

        // Redirects - WHATWG Fetch handles redirects manually, so disable
        _ = curl.easy_setopt(handle, curl.CURLOPT_FOLLOWLOCATION, @as(c_long, if (request.follow_redirects) 1 else 0));
        if (request.follow_redirects) {
            _ = curl.easy_setopt(handle, curl.CURLOPT_MAXREDIRS, @as(c_long, @intCast(request.max_redirects)));
        }

        // TLS options
        _ = curl.easy_setopt(handle, curl.CURLOPT_SSL_VERIFYPEER, @as(c_long, if (request.cert_options.verify_peer) 1 else 0));
        _ = curl.easy_setopt(handle, curl.CURLOPT_SSL_VERIFYHOST, @as(c_long, if (request.cert_options.verify_host) 2 else 0));

        if (request.cert_options.ca_bundle_path) |ca_path| {
            const ca_z = try ctx.allocator.dupeZ(u8, ca_path);
            defer ctx.allocator.free(ca_z);
            _ = curl.easy_setopt(handle, curl.CURLOPT_CAINFO, ca_z.ptr);
        }

        // Proxy
        if (request.proxy) |proxy| {
            const proxy_z = try ctx.allocator.dupeZ(u8, proxy.url);
            defer ctx.allocator.free(proxy_z);
            _ = curl.easy_setopt(handle, curl.CURLOPT_PROXY, proxy_z.ptr);

            if (proxy.username != null and proxy.password != null) {
                const userpwd = try std.fmt.allocPrint(ctx.allocator, "{s}:{s}", .{
                    proxy.username.?,
                    proxy.password.?,
                });
                defer ctx.allocator.free(userpwd);
                // Create null-terminated copy for curl
                const userpwd_z = try ctx.allocator.dupeZ(u8, userpwd);
                defer ctx.allocator.free(userpwd_z);
                _ = curl.easy_setopt(handle, curl.CURLOPT_PROXYUSERPWD, userpwd_z.ptr);
            }

            if (proxy.no_proxy) |no_proxy| {
                const no_proxy_z = try ctx.allocator.dupeZ(u8, no_proxy);
                defer ctx.allocator.free(no_proxy_z);
                _ = curl.easy_setopt(handle, curl.CURLOPT_NOPROXY, no_proxy_z.ptr);
            }
        }

        // Accept gzip/deflate compression
        _ = curl.easy_setopt(handle, curl.CURLOPT_ACCEPT_ENCODING, "");

        // Verbose logging for debugging
        if (request.verbose) {
            _ = curl.easy_setopt(handle, curl.CURLOPT_VERBOSE, @as(c_long, 1));
        }

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

    fn parseHeaders(ctx: *CallbackContext) !void {
        // Parse raw headers into name-value pairs
        const raw = ctx.raw_headers.items;
        var lines = std.mem.splitSequence(u8, raw, "\r\n");

        while (lines.next()) |line| {
            // Skip empty lines and status line
            if (line.len == 0) continue;
            if (std.mem.startsWith(u8, line, "HTTP/")) continue;

            // Find colon separator
            if (std.mem.indexOf(u8, line, ":")) |colon_pos| {
                const name = std.mem.trim(u8, line[0..colon_pos], " \t");
                const value = std.mem.trim(u8, line[colon_pos + 1 ..], " \t");

                if (name.len > 0) {
                    const header = NetworkResponse.Header{
                        .name = try ctx.allocator.dupe(u8, name),
                        .value = try ctx.allocator.dupe(u8, value),
                    };
                    try ctx.response_headers.append(ctx.allocator, header);
                }
            }
        }
    }

    fn abortImpl(ptr: *anyopaque) void {
        const self: *Self = @ptrCast(@alignCast(ptr));
        self.aborted.store(true, .seq_cst);
    }

    fn supportsStreamingImpl(_: *anyopaque) bool {
        // Full streaming would require curl_multi interface
        // For now, we collect entire response
        return false;
    }

    fn getNameImpl(_: *anyopaque) []const u8 {
        return "LibcurlBackend";
    }

    fn deinitImpl(ptr: *anyopaque) void {
        const self: *Self = @ptrCast(@alignCast(ptr));
        self.deinit();
    }
};

// =============================================================================
// Curl Callbacks
// =============================================================================

/// Write callback - called when response body data is received
fn writeCallback(data: [*]u8, size: usize, nmemb: usize, userdata: *anyopaque) callconv(.c) usize {
    const ctx: *LibcurlBackend.CallbackContext = @ptrCast(@alignCast(userdata));

    // Check abort flag
    if (ctx.aborted.load(.seq_cst)) {
        return 0; // Signal abort
    }

    const total_size = size * nmemb;
    ctx.response_body.appendSlice(ctx.allocator, data[0..total_size]) catch {
        return 0; // Signal error
    };
    return total_size;
}

/// Header callback - called for each header line received
fn headerCallback(data: [*]u8, size: usize, nmemb: usize, userdata: *anyopaque) callconv(.c) usize {
    const ctx: *LibcurlBackend.CallbackContext = @ptrCast(@alignCast(userdata));

    // Check abort flag
    if (ctx.aborted.load(.seq_cst)) {
        return 0; // Signal abort
    }

    const total_size = size * nmemb;
    ctx.raw_headers.appendSlice(ctx.allocator, data[0..total_size]) catch {
        return 0; // Signal error
    };
    return total_size;
}

/// Progress callback - used for abort detection
fn progressCallback(
    userdata: *anyopaque,
    _: c_longlong, // dltotal
    _: c_longlong, // dlnow
    _: c_longlong, // ultotal
    _: c_longlong, // ulnow
) callconv(.c) c_int {
    const ctx: *LibcurlBackend.CallbackContext = @ptrCast(@alignCast(userdata));

    // Return non-zero to abort transfer
    if (ctx.aborted.load(.seq_cst)) {
        return 1;
    }
    return 0;
}

// =============================================================================
// Tests
// =============================================================================

test "LibcurlBackend - init and deinit" {
    const allocator = std.testing.allocator;

    try globalInit();
    defer globalCleanup();

    const back = try LibcurlBackend.init(allocator);
    defer back.deinit();

    try std.testing.expectEqualStrings("LibcurlBackend", back.getBackend().getName());
    try std.testing.expect(!back.getBackend().supportsStreaming());
}

test "LibcurlBackend - global init reference counting" {
    // First init
    try globalInit();
    try std.testing.expectEqual(@as(usize, 1), global_init_count);

    // Second init
    try globalInit();
    try std.testing.expectEqual(@as(usize, 2), global_init_count);

    // First cleanup
    globalCleanup();
    try std.testing.expectEqual(@as(usize, 1), global_init_count);

    // Second cleanup
    globalCleanup();
    try std.testing.expectEqual(@as(usize, 0), global_init_count);
}

test "LibcurlBackend - abort flag" {
    const allocator = std.testing.allocator;

    try globalInit();
    defer globalCleanup();

    const back = try LibcurlBackend.init(allocator);
    defer back.deinit();

    // Initially not aborted
    try std.testing.expect(!back.aborted.load(.seq_cst));

    // Abort
    back.getBackend().abort();

    // Now aborted
    try std.testing.expect(back.aborted.load(.seq_cst));
}

test "LibcurlBackend - CallbackContext init and deinit" {
    const allocator = std.testing.allocator;

    try globalInit();
    defer globalCleanup();

    const back = try LibcurlBackend.init(allocator);
    defer back.deinit();

    // Create callback context
    var ctx = LibcurlBackend.CallbackContext.init(allocator, &back.aborted);
    defer ctx.deinit();

    // Verify empty state
    try std.testing.expectEqual(@as(usize, 0), ctx.response_body.items.len);
    try std.testing.expectEqual(@as(usize, 0), ctx.response_headers.items.len);
    try std.testing.expectEqual(@as(usize, 0), ctx.raw_headers.items.len);
}

test "LibcurlBackend - CallbackContext accumulates data" {
    const allocator = std.testing.allocator;

    try globalInit();
    defer globalCleanup();

    const back = try LibcurlBackend.init(allocator);
    defer back.deinit();

    var ctx = LibcurlBackend.CallbackContext.init(allocator, &back.aborted);
    defer ctx.deinit();

    // Simulate body data accumulation
    try ctx.response_body.appendSlice(allocator, "Hello, ");
    try ctx.response_body.appendSlice(allocator, "World!");

    try std.testing.expectEqualStrings("Hello, World!", ctx.response_body.items);

    // Simulate header data accumulation
    try ctx.raw_headers.appendSlice(allocator, "HTTP/1.1 200 OK\r\n");
    try ctx.raw_headers.appendSlice(allocator, "Content-Type: text/plain\r\n");

    try std.testing.expect(std.mem.startsWith(u8, ctx.raw_headers.items, "HTTP/1.1 200 OK"));
}

test "LibcurlBackend - supportsStreaming returns false" {
    const allocator = std.testing.allocator;

    try globalInit();
    defer globalCleanup();

    const back = try LibcurlBackend.init(allocator);
    defer back.deinit();

    // LibcurlBackend uses easy interface, not streaming
    try std.testing.expect(!back.getBackend().supportsStreaming());
}

test "LibcurlBackend - multiple init/cleanup cycles" {
    const allocator = std.testing.allocator;

    // Cycle 1
    {
        try globalInit();
        defer globalCleanup();

        const back = try LibcurlBackend.init(allocator);
        defer back.deinit();

        try std.testing.expectEqualStrings("LibcurlBackend", back.getBackend().getName());
    }

    // Verify cleanup happened
    try std.testing.expectEqual(@as(usize, 0), global_init_count);

    // Cycle 2
    {
        try globalInit();
        defer globalCleanup();

        const back = try LibcurlBackend.init(allocator);
        defer back.deinit();

        try std.testing.expect(!back.aborted.load(.seq_cst));
    }

    try std.testing.expectEqual(@as(usize, 0), global_init_count);
}

test "LibcurlBackend - concurrent global init" {
    // Test that multiple inits increment correctly
    try globalInit();
    try globalInit();
    try globalInit();

    try std.testing.expectEqual(@as(usize, 3), global_init_count);

    globalCleanup();
    try std.testing.expectEqual(@as(usize, 2), global_init_count);

    globalCleanup();
    globalCleanup();

    try std.testing.expectEqual(@as(usize, 0), global_init_count);
}
