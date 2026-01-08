//! Connection Pool for libcurl - WHATWG Fetch Implementation
//!
//! Provides connection pooling and reuse using libcurl's multi interface.
//! Per WHATWG Fetch spec, connections should be pooled by (partition key, origin, credentials).
//!
//! Spec: https://fetch.spec.whatwg.org/#connections
//!
//! Features:
//! - Connection reuse for same host
//! - Maximum connections per host (default: 6 per HTTP spec)
//! - Maximum total connections
//! - Shared DNS cache
//! - Shared SSL session cache
//! - Thread-safe with mutex protection
//!
//! Usage:
//! ```zig
//! const pool = try ConnectionPool.init(allocator);
//! defer pool.deinit();
//!
//! // Option 1: Synchronous request through pool
//! var response = try pool.send(allocator, &request);
//! defer response.deinit();
//!
//! // Option 2: Use pool with LibcurlBackend
//! var backend = try LibcurlBackend.initWithPool(allocator, pool);
//! defer backend.deinit();
//! ```

const std = @import("std");
const Allocator = std.mem.Allocator;
const curl = @import("curl_ffi.zig");
const curl_error = @import("curl_error.zig");
const backend_mod = @import("backend.zig");
const NetworkRequest = backend_mod.NetworkRequest;
const NetworkResponse = backend_mod.NetworkResponse;
const NetworkError = backend_mod.NetworkError;
const HttpVersion = backend_mod.HttpVersion;

// =============================================================================
// Connection Pool
// =============================================================================

/// ConnectionPool manages a pool of HTTP connections using curl_multi.
///
/// Connections are reused for subsequent requests to the same host,
/// reducing latency from TCP handshakes and TLS negotiations.
pub const ConnectionPool = struct {
    allocator: Allocator,
    multi_handle: *curl.CURLM,
    mutex: std.Thread.Mutex,

    /// Maximum connections to a single host (per HTTP spec: 6)
    max_connections_per_host: u32,

    /// Maximum total connections in pool
    max_total_connections: u32,

    /// Active easy handles in pool (for cleanup)
    active_handles: std.AutoHashMap(*curl.CURL, *RequestContext),

    const Self = @This();

    /// Default max connections per host (HTTP/1.1 recommendation)
    pub const DEFAULT_MAX_HOST_CONNECTIONS: u32 = 6;

    /// Default max total connections
    pub const DEFAULT_MAX_TOTAL_CONNECTIONS: u32 = 256;

    /// Configuration options for the connection pool
    pub const Options = struct {
        max_connections_per_host: u32 = DEFAULT_MAX_HOST_CONNECTIONS,
        max_total_connections: u32 = DEFAULT_MAX_TOTAL_CONNECTIONS,
    };

    /// Context for tracking an in-flight request
    pub const RequestContext = struct {
        allocator: Allocator,
        response_body: std.ArrayList(u8),
        response_headers: std.ArrayList(NetworkResponse.Header),
        raw_headers: std.ArrayList(u8),
        aborted: std.atomic.Value(bool),
        completed: std.atomic.Value(bool),
        result_code: curl.CURLcode,
        easy_handle: *curl.CURL,

        pub fn init(allocator: Allocator, easy_handle: *curl.CURL) RequestContext {
            return .{
                .allocator = allocator,
                .response_body = .empty,
                .response_headers = .empty,
                .raw_headers = .empty,
                .aborted = std.atomic.Value(bool).init(false),
                .completed = std.atomic.Value(bool).init(false),
                .result_code = curl.CURLE_OK,
                .easy_handle = easy_handle,
            };
        }

        pub fn deinit(self: *RequestContext) void {
            self.response_body.deinit(self.allocator);
            for (self.response_headers.items) |header| {
                self.allocator.free(header.name);
                self.allocator.free(header.value);
            }
            self.response_headers.deinit(self.allocator);
            self.raw_headers.deinit(self.allocator);
        }
    };

    /// Initialize a new connection pool.
    pub fn init(allocator: Allocator) !*Self {
        return initWithOptions(allocator, .{});
    }

    /// Initialize with custom options.
    pub fn initWithOptions(allocator: Allocator, options: Options) !*Self {
        const multi = curl.multi_init() orelse return error.MultiInitFailed;
        errdefer _ = curl.multi_cleanup(multi);

        // Configure multi handle limits
        _ = curl.multi_setopt(multi, curl.CURLMOPT_MAX_HOST_CONNECTIONS, @as(c_long, @intCast(options.max_connections_per_host)));
        _ = curl.multi_setopt(multi, curl.CURLMOPT_MAX_TOTAL_CONNECTIONS, @as(c_long, @intCast(options.max_total_connections)));

        const self = try allocator.create(Self);
        self.* = .{
            .allocator = allocator,
            .multi_handle = multi,
            .mutex = .{},
            .max_connections_per_host = options.max_connections_per_host,
            .max_total_connections = options.max_total_connections,
            .active_handles = std.AutoHashMap(*curl.CURL, *RequestContext).init(allocator),
        };

        return self;
    }

    /// Clean up pool and all connections.
    pub fn deinit(self: *Self) void {
        // Lock for cleanup operations (but don't defer unlock since we free self)
        self.mutex.lock();

        // Remove and cleanup all active handles
        var it = self.active_handles.iterator();
        while (it.next()) |entry| {
            const easy_handle = entry.key_ptr.*;
            const ctx = entry.value_ptr.*;

            _ = curl.multi_remove_handle(self.multi_handle, easy_handle);
            curl.easy_cleanup(easy_handle);
            ctx.deinit();
            self.allocator.destroy(ctx);
        }
        self.active_handles.deinit();

        _ = curl.multi_cleanup(self.multi_handle);

        // Store allocator before destroying self
        const allocator = self.allocator;

        // Unlock before destroying (mutex is part of self)
        self.mutex.unlock();

        // Now safe to destroy
        allocator.destroy(self);
    }

    /// Send a request through the connection pool.
    /// This is a synchronous operation that blocks until the request completes.
    pub fn send(self: *Self, allocator: Allocator, request: *const NetworkRequest) NetworkError!NetworkResponse {
        // Create easy handle
        const easy_handle = curl.easy_init() orelse return NetworkError.OutOfMemory;
        errdefer curl.easy_cleanup(easy_handle);

        // Create request context
        const ctx = allocator.create(RequestContext) catch return NetworkError.OutOfMemory;
        ctx.* = RequestContext.init(allocator, easy_handle);
        errdefer {
            ctx.deinit();
            allocator.destroy(ctx);
        }

        // Configure the request
        configureRequest(easy_handle, request, ctx) catch return NetworkError.OutOfMemory;

        // Add to multi handle
        {
            self.mutex.lock();
            defer self.mutex.unlock();

            const add_result = curl.multi_add_handle(self.multi_handle, easy_handle);
            if (add_result != curl.CURLM_OK) {
                return NetworkError.ProtocolError;
            }

            self.active_handles.put(easy_handle, ctx) catch return NetworkError.OutOfMemory;
        }

        // Poll until this request completes
        while (!ctx.completed.load(.seq_cst)) {
            if (ctx.aborted.load(.seq_cst)) {
                self.cancelRequest(easy_handle, ctx, allocator);
                return NetworkError.Aborted;
            }

            self.pollOnce(100) catch {}; // Poll with 100ms timeout
        }

        // Remove from multi (connection stays in pool for reuse)
        {
            self.mutex.lock();
            defer self.mutex.unlock();
            _ = curl.multi_remove_handle(self.multi_handle, easy_handle);
            _ = self.active_handles.remove(easy_handle);
        }

        // Check result
        if (ctx.result_code != curl.CURLE_OK) {
            const err = curl_error.mapCurlError(ctx.result_code);
            curl.easy_cleanup(easy_handle);
            ctx.deinit();
            allocator.destroy(ctx);
            return err;
        }

        // Build response (transfers ownership of data)
        const response = buildResponse(allocator, easy_handle, ctx, request) catch {
            curl.easy_cleanup(easy_handle);
            ctx.deinit();
            allocator.destroy(ctx);
            return NetworkError.OutOfMemory;
        };

        // Cleanup easy handle (connection cached in multi)
        curl.easy_cleanup(easy_handle);
        allocator.destroy(ctx);

        return response;
    }

    /// Poll for activity on all handles.
    /// Blocks up to timeout_ms milliseconds.
    pub fn pollOnce(self: *Self, timeout_ms: i32) !void {
        self.mutex.lock();
        defer self.mutex.unlock();

        var numfds: c_int = 0;
        const poll_result = curl.multi_poll(self.multi_handle, @intCast(timeout_ms), &numfds);
        if (poll_result != curl.CURLM_OK) {
            return error.PollFailed;
        }

        // Perform transfers
        var still_running: c_int = 0;
        _ = curl.multi_perform(self.multi_handle, &still_running);

        // Check for completed transfers
        while (true) {
            var msgs_in_queue: c_int = 0;
            const msg = curl.multi_info_read(self.multi_handle, &msgs_in_queue);
            if (msg == null) break;

            if (msg.?.msg == curl.CURLMSG_DONE) {
                // easy_handle is ?*anyopaque from C, cast to our handle type
                if (msg.?.easy_handle) |handle_ptr| {
                    const easy_handle: *curl.CURL = @ptrCast(handle_ptr);
                    // data is an extern union, so we can access .result directly
                    const result_code = msg.?.data.result;

                    if (self.active_handles.get(easy_handle)) |ctx| {
                        ctx.result_code = result_code;
                        ctx.completed.store(true, .seq_cst);
                    }
                }
            }
        }
    }

    /// Cancel an in-progress request.
    fn cancelRequest(self: *Self, easy_handle: *curl.CURL, ctx: *RequestContext, allocator: Allocator) void {
        self.mutex.lock();
        defer self.mutex.unlock();

        _ = curl.multi_remove_handle(self.multi_handle, easy_handle);
        _ = self.active_handles.remove(easy_handle);
        curl.easy_cleanup(easy_handle);
        ctx.deinit();
        allocator.destroy(ctx);
    }

    /// Get statistics about the pool.
    pub fn getStats(self: *Self) PoolStats {
        self.mutex.lock();
        defer self.mutex.unlock();

        return .{
            .active_requests = self.active_handles.count(),
            .max_per_host = self.max_connections_per_host,
            .max_total = self.max_total_connections,
        };
    }

    /// Pool statistics
    pub const PoolStats = struct {
        active_requests: u32,
        max_per_host: u32,
        max_total: u32,
    };
};

// =============================================================================
// Request Configuration (shared with LibcurlBackend)
// =============================================================================

fn configureRequest(handle: *curl.CURL, request: *const NetworkRequest, ctx: *ConnectionPool.RequestContext) !void {
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

    // TLS options - proper certificate verification with trust store support
    _ = curl.easy_setopt(handle, curl.CURLOPT_SSL_VERIFYPEER, @as(c_long, if (request.cert_options.verify_peer) 1 else 0));
    _ = curl.easy_setopt(handle, curl.CURLOPT_SSL_VERIFYHOST, @as(c_long, if (request.cert_options.verify_host) 2 else 0));

    // Use custom CA bundle if trust store or ca_bundle_path is configured
    if (request.cert_options.trust_store) |trust_store| {
        if (trust_store.getCaBundlePath()) |ca_path| {
            const ca_z = try ctx.allocator.dupeZ(u8, ca_path);
            defer ctx.allocator.free(ca_z);
            _ = curl.easy_setopt(handle, curl.CURLOPT_CAINFO, ca_z.ptr);
        }
    } else if (request.cert_options.ca_bundle_path) |ca_path| {
        const ca_z = try ctx.allocator.dupeZ(u8, ca_path);
        defer ctx.allocator.free(ca_z);
        _ = curl.easy_setopt(handle, curl.CURLOPT_CAINFO, ca_z.ptr);
    }
    // If neither trust_store nor ca_bundle_path is set, curl uses system CA store

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

    // Accept compression
    _ = curl.easy_setopt(handle, curl.CURLOPT_ACCEPT_ENCODING, "");

    // Verbose logging
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

fn buildResponse(allocator: Allocator, handle: *curl.CURL, ctx: *ConnectionPool.RequestContext, request: *const NetworkRequest) !NetworkResponse {
    // Parse headers
    try parseHeaders(ctx);

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

    // Resource Timing
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

    var num_connects: c_long = 0;
    _ = curl.easy_getinfo(handle, curl.CURLINFO_NUM_CONNECTS, &num_connects);

    const http_version: HttpVersion = switch (http_version_raw) {
        curl.CURL_HTTP_VERSION_1_0 => .http_1_0,
        curl.CURL_HTTP_VERSION_1_1 => .http_1_1,
        curl.CURL_HTTP_VERSION_2_0 => .http_2,
        curl.CURL_HTTP_VERSION_3 => .http_3,
        else => .http_1_1,
    };

    // Transfer ownership of collected data
    const headers = try ctx.response_headers.toOwnedSlice(allocator);

    const body = if (ctx.response_body.items.len > 0)
        try ctx.response_body.toOwnedSlice(allocator)
    else
        null;

    // Copy strings
    const final_url = if (effective_url != null and
        !std.mem.eql(u8, std.mem.span(effective_url.?), request.url))
        try allocator.dupe(u8, std.mem.span(effective_url.?))
    else
        null;

    const remote_ip = if (primary_ip != null)
        try allocator.dupe(u8, std.mem.span(primary_ip.?))
    else
        null;

    // Clean up context's raw headers (body and headers transferred)
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
        .dns_lookup_time_ms = @intFromFloat(namelookup_time * 1000),
        .connect_time_ms = @intFromFloat(connect_time * 1000),
        .app_connect_time_ms = @intFromFloat(appconnect_time * 1000),
        .pretransfer_time_ms = @intFromFloat(pretransfer_time * 1000),
        .redirect_time_ms = @intFromFloat(redirect_time * 1000),
        .connection_reused = (num_connects == 0),
    };
}

fn parseHeaders(ctx: *ConnectionPool.RequestContext) !void {
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
                try ctx.response_headers.append(ctx.allocator, header);
            }
        }
    }
}

// =============================================================================
// Curl Callbacks
// =============================================================================

fn writeCallback(data: [*]u8, size: usize, nmemb: usize, userdata: *anyopaque) callconv(.c) usize {
    const ctx: *ConnectionPool.RequestContext = @ptrCast(@alignCast(userdata));

    if (ctx.aborted.load(.seq_cst)) {
        return 0;
    }

    const total_size = size * nmemb;
    ctx.response_body.appendSlice(ctx.allocator, data[0..total_size]) catch {
        return 0;
    };
    return total_size;
}

fn headerCallback(data: [*]u8, size: usize, nmemb: usize, userdata: *anyopaque) callconv(.c) usize {
    const ctx: *ConnectionPool.RequestContext = @ptrCast(@alignCast(userdata));

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
    const ctx: *ConnectionPool.RequestContext = @ptrCast(@alignCast(userdata));

    if (ctx.aborted.load(.seq_cst)) {
        return 1;
    }
    return 0;
}

// =============================================================================
// Global Pool (singleton pattern)
// =============================================================================

var global_pool: ?*ConnectionPool = null;
var global_pool_mutex: std.Thread.Mutex = .{};

/// Get or create the global connection pool.
/// The global pool is shared across all requests and provides
/// maximum connection reuse efficiency.
pub fn getGlobalPool(allocator: Allocator) !*ConnectionPool {
    global_pool_mutex.lock();
    defer global_pool_mutex.unlock();

    if (global_pool == null) {
        global_pool = try ConnectionPool.init(allocator);
    }
    return global_pool.?;
}

/// Cleanup the global pool. Call at program shutdown.
pub fn cleanupGlobalPool() void {
    global_pool_mutex.lock();
    defer global_pool_mutex.unlock();

    if (global_pool) |pool| {
        pool.deinit();
        global_pool = null;
    }
}

// =============================================================================
// Tests
// =============================================================================

test "ConnectionPool - init and deinit" {
    const allocator = std.testing.allocator;

    // Must init curl globally first
    const curl_backend = @import("curl_backend.zig");
    try curl_backend.globalInit();
    defer curl_backend.globalCleanup();

    const pool = try ConnectionPool.init(allocator);
    defer pool.deinit();

    const stats = pool.getStats();
    try std.testing.expectEqual(@as(u32, 0), stats.active_requests);
    try std.testing.expectEqual(ConnectionPool.DEFAULT_MAX_HOST_CONNECTIONS, stats.max_per_host);
    try std.testing.expectEqual(ConnectionPool.DEFAULT_MAX_TOTAL_CONNECTIONS, stats.max_total);
}

test "ConnectionPool - custom options" {
    const allocator = std.testing.allocator;

    const curl_backend = @import("curl_backend.zig");
    try curl_backend.globalInit();
    defer curl_backend.globalCleanup();

    const pool = try ConnectionPool.initWithOptions(allocator, .{
        .max_connections_per_host = 10,
        .max_total_connections = 100,
    });
    defer pool.deinit();

    const stats = pool.getStats();
    try std.testing.expectEqual(@as(u32, 10), stats.max_per_host);
    try std.testing.expectEqual(@as(u32, 100), stats.max_total);
}

test "ConnectionPool - RequestContext init and deinit" {
    const allocator = std.testing.allocator;

    const curl_backend = @import("curl_backend.zig");
    try curl_backend.globalInit();
    defer curl_backend.globalCleanup();

    const easy_handle = curl.easy_init() orelse return error.InitFailed;
    defer curl.easy_cleanup(easy_handle);

    var ctx = ConnectionPool.RequestContext.init(allocator, easy_handle);
    defer ctx.deinit();

    try std.testing.expectEqual(@as(usize, 0), ctx.response_body.items.len);
    try std.testing.expect(!ctx.completed.load(.seq_cst));
    try std.testing.expect(!ctx.aborted.load(.seq_cst));
}

test "ConnectionPool - global pool singleton" {
    const allocator = std.testing.allocator;

    const curl_backend = @import("curl_backend.zig");
    try curl_backend.globalInit();
    defer curl_backend.globalCleanup();

    // Get global pool twice - should be same instance
    const pool1 = try getGlobalPool(allocator);
    const pool2 = try getGlobalPool(allocator);

    try std.testing.expectEqual(pool1, pool2);

    // Cleanup
    cleanupGlobalPool();

    // Ensure it was cleaned up
    global_pool_mutex.lock();
    try std.testing.expect(global_pool == null);
    global_pool_mutex.unlock();
}
