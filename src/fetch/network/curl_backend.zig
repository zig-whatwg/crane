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
const CurlCookieManager = @import("curl_cookies.zig").CurlCookieManager;

// =============================================================================
// Global State Management
// =============================================================================

/// Global initialization state (reference counted, thread-safe)
var global_init_count: usize = 0;
var global_init_mutex: std.Thread.Mutex = .{};

/// Global curl share handle for connection pooling across easy handles.
/// This enables connection reuse when creating new easy handles for each request.
/// Without this, each new easy handle creates its own connection pool (default 5 connections),
/// leading to socket exhaustion after ~25 requests.
var global_share: ?*curl.CURLSH = null;

/// Mutexes for curl share locking (one per data type)
/// CURL_LOCK_DATA_CONNECT = 5, CURL_LOCK_DATA_DNS = 2
/// We allocate enough slots for all lock data types (up to 8)
var share_mutexes: [8]std.Thread.Mutex = [_]std.Thread.Mutex{.{}} ** 8;

/// Track lock/unlock calls for debugging
var lock_call_count: usize = 0;
var unlock_call_count: usize = 0;

/// Lock callback for curl share - called when curl needs to access shared data
fn shareLockCallback(
    _: *curl.CURL,
    data: c_int,
    access: c_int, // access type (shared/single) - we use exclusive lock regardless
    _: ?*anyopaque,
) callconv(.c) void {
    lock_call_count += 1;
    if (lock_call_count <= 5 or lock_call_count % 100 == 0) {
        // Only log first few calls and then every 100th to avoid spam
        const data_type_name = switch (data) {
            2 => "DNS",
            5 => "CONNECT",
            else => "OTHER",
        };
        std.debug.print("[CURL SHARE] Lock #{}: data={} ({s}), access={}\n", .{ lock_call_count, data, data_type_name, access });
    }
    if (data >= 0 and data < share_mutexes.len) {
        share_mutexes[@intCast(data)].lock();
    }
}

/// Unlock callback for curl share - called when curl is done with shared data
fn shareUnlockCallback(
    _: *curl.CURL,
    data: c_int,
    _: ?*anyopaque,
) callconv(.c) void {
    unlock_call_count += 1;
    if (unlock_call_count <= 5 or unlock_call_count % 100 == 0) {
        const data_type_name = switch (data) {
            2 => "DNS",
            5 => "CONNECT",
            else => "OTHER",
        };
        std.debug.print("[CURL SHARE] Unlock #{}: data={} ({s})\n", .{ unlock_call_count, data, data_type_name });
    }
    if (data >= 0 and data < share_mutexes.len) {
        share_mutexes[@intCast(data)].unlock();
    }
}

/// Initialize libcurl globally.
/// Thread-safe and reference counted - can be called multiple times.
/// Must call globalCleanup() the same number of times.
pub fn globalInit() !void {
    global_init_mutex.lock();
    defer global_init_mutex.unlock();

    std.debug.print("[CURL] globalInit called, current count: {}\n", .{global_init_count});

    if (global_init_count == 0) {
        std.debug.print("[CURL] First init - initializing libcurl globally\n", .{});
        const result = curl.global_init(curl.CURL_GLOBAL_DEFAULT);
        if (result != curl.CURLE_OK) {
            std.debug.print("[CURL] ERROR: global_init failed with code: {}\n", .{result});
            return error.CurlGlobalInitFailed;
        }

        // Create global share for connection pooling
        global_share = curl.share_init();
        if (global_share) |share| {
            std.debug.print("[CURL] Created global share: {*}\n", .{share});
            // Set lock/unlock callbacks for thread safety (REQUIRED for multi-threaded use)
            _ = curl.share_setopt(share, curl.CURLSHOPT_LOCKFUNC, @as(*const anyopaque, @ptrCast(&shareLockCallback)));
            _ = curl.share_setopt(share, curl.CURLSHOPT_UNLOCKFUNC, @as(*const anyopaque, @ptrCast(&shareUnlockCallback)));

            // Enable connection sharing - this is the key to avoiding socket exhaustion
            _ = curl.share_setopt(share, curl.CURLSHOPT_SHARE, curl.CURL_LOCK_DATA_CONNECT);
            // Also share DNS cache for efficiency
            _ = curl.share_setopt(share, curl.CURLSHOPT_SHARE, curl.CURL_LOCK_DATA_DNS);
            std.debug.print("[CURL] Global share configured with connection and DNS sharing\n", .{});
        } else {
            std.debug.print("[CURL] WARNING: Failed to create global share!\n", .{});
        }
    }
    global_init_count += 1;
    std.debug.print("[CURL] globalInit complete, new count: {}\n", .{global_init_count});
}

/// Decrement global init reference count.
/// When count reaches zero, libcurl global cleanup is performed.
pub fn globalCleanup() void {
    global_init_mutex.lock();
    defer global_init_mutex.unlock();

    std.debug.print("[CURL] globalCleanup called, current count: {}\n", .{global_init_count});

    if (global_init_count > 0) {
        global_init_count -= 1;
        std.debug.print("[CURL] Decremented count to: {}\n", .{global_init_count});
        if (global_init_count == 0) {
            std.debug.print("[CURL] Count is zero - performing full cleanup\n", .{});
            // Clean up global share before global cleanup
            if (global_share) |share| {
                std.debug.print("[CURL] Cleaning up global share: {*}\n", .{share});
                _ = curl.share_cleanup(share);
                global_share = null;
            }
            curl.global_cleanup();
            std.debug.print("[CURL] Full cleanup complete\n", .{});
        }
    } else {
        std.debug.print("[CURL] WARNING: globalCleanup called but count already 0!\n", .{});
    }
}

/// Get the global share handle for connection pooling.
/// Returns null if globalInit() hasn't been called.
pub fn getGlobalShare() ?*curl.CURLSH {
    global_init_mutex.lock();
    defer global_init_mutex.unlock();
    return global_share;
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

    /// Shared cookie manager (null = cookies disabled)
    cookie_manager: ?*CurlCookieManager,

    /// Whether we own the cookie manager (should deinit on cleanup)
    owns_cookie_manager: bool,

    const Self = @This();

    /// Options for LibcurlBackend initialization
    pub const Options = struct {
        /// Enable cookie handling (default: true)
        enable_cookies: bool = true,

        /// Custom cookie manager (null = create new one)
        /// If provided, caller retains ownership
        cookie_manager: ?*CurlCookieManager = null,
    };

    /// Initialize a new LibcurlBackend.
    /// Automatically calls globalInit() if not already initialized.
    pub fn init(allocator: Allocator) !*Self {
        return initWithOptions(allocator, .{});
    }

    /// Initialize with options (including cookie configuration)
    /// Automatically calls globalInit() if not already initialized.
    pub fn initWithOptions(allocator: Allocator, options: Options) !*Self {
        // Ensure global curl is initialized (idempotent, thread-safe)
        // We only call globalInit if not already initialized, to avoid
        // incrementing the reference count on every request.
        if (getGlobalShare() == null) {
            std.debug.print("[CURL] First backend init - calling globalInit\n", .{});
            try globalInit();
        } else {
            std.debug.print("[CURL] Backend init - global share already exists, skipping globalInit\n", .{});
        }

        const self = try allocator.create(Self);
        errdefer allocator.destroy(self);

        var cookie_manager: ?*CurlCookieManager = null;
        var owns_manager = false;

        if (options.enable_cookies) {
            if (options.cookie_manager) |cm| {
                cookie_manager = cm;
                owns_manager = false; // Caller owns it
            } else {
                cookie_manager = try CurlCookieManager.init(allocator, null);
                owns_manager = true; // We own it
            }
        }

        self.* = .{
            .allocator = allocator,
            .aborted = std.atomic.Value(bool).init(false),
            .cookie_manager = cookie_manager,
            .owns_cookie_manager = owns_manager,
        };
        return self;
    }

    /// Clean up backend resources.
    ///
    /// NOTE: We intentionally do NOT call globalCleanup() here.
    /// The global curl state (including the shared connection pool) should persist
    /// for the lifetime of the application to enable connection reuse across requests.
    /// Each request creates a new LibcurlBackend, but they all share the same global
    /// connection pool via CURLOPT_SHARE.
    pub fn deinit(self: *Self) void {
        std.debug.print("[CURL] Backend deinit (NOT calling globalCleanup - share persists)\n", .{});
        if (self.owns_cookie_manager) {
            if (self.cookie_manager) |cm| {
                cm.deinit();
            }
        }
        self.allocator.destroy(self);

        // NOTE: We used to call globalCleanup() here, but this caused the global share
        // to be destroyed after each request, preventing connection reuse.
        // The global state now persists for the application lifetime.
        // If you need explicit cleanup, call globalCleanup() directly at app shutdown.
    }

    /// Get the cookie manager (for sharing with CookieStore API)
    pub fn getCookieManager(self: *Self) ?*CurlCookieManager {
        return self.cookie_manager;
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

        // Strings that must persist until request completes (curl doesn't copy them)
        url_z: ?[:0]u8 = null,
        method_z: ?[:0]u8 = null,
        header_list: ?*curl.curl_slist = null,

        fn init(allocator: Allocator, aborted: *std.atomic.Value(bool)) CallbackContext {
            return .{
                .allocator = allocator,
                .response_body = .empty,
                .response_headers = .empty,
                .raw_headers = .empty,
                .aborted = aborted,
                .url_z = null,
                .method_z = null,
                .header_list = null,
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

            // Free strings that were stored for curl
            if (self.url_z) |url| self.allocator.free(url);
            if (self.method_z) |method| self.allocator.free(method);
            if (self.header_list) |list| curl.slist_free_all(list);
        }
    };

    /// Track request count for debugging
    var request_counter: usize = 0;

    fn sendImpl(ptr: *anyopaque, allocator: Allocator, request: *const NetworkRequest) NetworkError!NetworkResponse {
        const self: *Self = @ptrCast(@alignCast(ptr));

        // Increment and get request number
        request_counter += 1;
        const req_num = request_counter;

        std.debug.print("\n[CURL REQUEST #{}] ========================================\n", .{req_num});
        std.debug.print("[CURL REQUEST #{}] URL: {s}\n", .{ req_num, request.url });
        std.debug.print("[CURL REQUEST #{}] Method: {s}\n", .{ req_num, request.method });
        std.debug.print("[CURL REQUEST #{}] Global share: {?}\n", .{ req_num, getGlobalShare() });
        std.debug.print("[CURL REQUEST #{}] Global init count: {}\n", .{ req_num, global_init_count });

        // Reset abort flag
        self.aborted.store(false, .seq_cst);

        // Create curl easy handle
        std.debug.print("[CURL REQUEST #{}] Creating easy handle...\n", .{req_num});
        const handle = curl.easy_init() orelse {
            std.debug.print("[CURL REQUEST #{}] ERROR: easy_init returned null!\n", .{req_num});
            return NetworkError.OutOfMemory;
        };
        std.debug.print("[CURL REQUEST #{}] Easy handle created: {*}\n", .{ req_num, handle });
        defer {
            std.debug.print("[CURL REQUEST #{}] Cleaning up easy handle: {*}\n", .{ req_num, handle });
            curl.easy_cleanup(handle);
        }

        // Attach to global share for connection pooling
        // This enables connection reuse across easy handles, preventing socket exhaustion
        if (getGlobalShare()) |share| {
            std.debug.print("[CURL REQUEST #{}] Attaching to global share: {*}\n", .{ req_num, share });
            _ = curl.easy_setopt(handle, curl.CURLOPT_SHARE, share);
        } else {
            std.debug.print("[CURL REQUEST #{}] WARNING: No global share available!\n", .{req_num});
        }

        // Attach cookie manager if available
        if (self.cookie_manager) |cm| {
            cm.attachToHandle(handle);
        }

        // Initialize callback context
        var ctx = CallbackContext.init(allocator, &self.aborted);
        defer {
            // Only cleanup on error - on success, data is transferred to response
        }

        // Configure request
        std.debug.print("[CURL REQUEST #{}] Configuring request...\n", .{req_num});
        configureRequest(handle, request, &ctx) catch {
            std.debug.print("[CURL REQUEST #{}] ERROR: configureRequest failed\n", .{req_num});
            ctx.deinit();
            return NetworkError.OutOfMemory;
        };
        std.debug.print("[CURL REQUEST #{}] Request configured\n", .{req_num});

        // Perform the request with retry for connection failures
        // The WPT server can hit connection limits under load
        var result: curl.CURLcode = undefined;
        var retry_count: u8 = 0;
        const max_retries: u8 = 3;
        std.debug.print("[CURL REQUEST #{}] Starting perform loop (max {} retries)...\n", .{ req_num, max_retries });
        while (retry_count < max_retries) : (retry_count += 1) {
            std.debug.print("[CURL REQUEST #{}] Attempt {}/{}: calling easy_perform...\n", .{ req_num, retry_count + 1, max_retries });
            result = curl.easy_perform(handle);
            std.debug.print("[CURL REQUEST #{}] easy_perform returned: {} (CURLE_OK={})\n", .{ req_num, result, curl.CURLE_OK });
            if (result == curl.CURLE_OK) break;

            // Only retry on connection failures
            if (result == curl.CURLE_COULDNT_CONNECT) {
                std.debug.print("[CURL REQUEST #{}] Connection failed, will retry after backoff\n", .{req_num});
                // Wait before retry (exponential backoff: 100ms, 200ms, 400ms)
                std.Thread.sleep(100_000_000 * std.math.pow(u64, 2, retry_count));
                continue;
            }
            std.debug.print("[CURL REQUEST #{}] Non-retriable error, breaking loop\n", .{req_num});
            break; // Non-retriable error
        }

        // Check for abort
        if (self.aborted.load(.seq_cst)) {
            std.debug.print("[CURL REQUEST #{}] Request was aborted\n", .{req_num});
            ctx.deinit();
            return NetworkError.Aborted;
        }

        // Check for errors
        if (result != curl.CURLE_OK) {
            std.debug.print("[CURL REQUEST #{}] ERROR: curl error code: {}\n", .{ req_num, result });
            ctx.deinit();
            return curl_error.mapCurlError(result);
        }

        std.debug.print("[CURL REQUEST #{}] Request completed successfully\n", .{req_num});

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

        // Debug output for response info
        std.debug.print("[CURL REQUEST #{}] Response info:\n", .{req_num});
        std.debug.print("[CURL REQUEST #{}]   Status code: {}\n", .{ req_num, status_code });
        std.debug.print("[CURL REQUEST #{}]   HTTP version: {}\n", .{ req_num, http_version_raw });
        std.debug.print("[CURL REQUEST #{}]   Body size: {} bytes\n", .{ req_num, ctx.response_body.items.len });
        std.debug.print("[CURL REQUEST #{}]   Total time: {d:.3}s\n", .{ req_num, total_time });
        std.debug.print("[CURL REQUEST #{}]   DNS lookup: {d:.3}s\n", .{ req_num, namelookup_time });
        std.debug.print("[CURL REQUEST #{}]   Connect time: {d:.3}s\n", .{ req_num, connect_time });
        std.debug.print("[CURL REQUEST #{}]   Num connects: {} (0 = reused)\n", .{ req_num, num_connects });
        if (primary_ip != null) {
            std.debug.print("[CURL REQUEST #{}]   Remote IP: {s}:{}\n", .{ req_num, std.mem.span(primary_ip.?), primary_port });
        }

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

        // Clean up remaining context resources (url_z, method_z, header_list, raw_headers)
        // Note: response_body and response_headers ownership transferred via toOwnedSlice
        ctx.raw_headers.deinit(allocator);
        if (ctx.url_z) |url| allocator.free(url);
        if (ctx.method_z) |method| allocator.free(method);
        if (ctx.header_list) |list| curl.slist_free_all(list);

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
        // URL (must be null-terminated, stored in ctx to persist until request completes)
        ctx.url_z = try ctx.allocator.dupeZ(u8, request.url);
        _ = curl.easy_setopt(handle, curl.CURLOPT_URL, ctx.url_z.?.ptr);

        // Method (stored in ctx to persist until request completes)
        if (!std.mem.eql(u8, request.method, "GET")) {
            ctx.method_z = try ctx.allocator.dupeZ(u8, request.method);
            _ = curl.easy_setopt(handle, curl.CURLOPT_CUSTOMREQUEST, ctx.method_z.?.ptr);
        }

        // Request body
        if (request.body) |body| {
            _ = curl.easy_setopt(handle, curl.CURLOPT_POSTFIELDS, body.ptr);
            _ = curl.easy_setopt(handle, curl.CURLOPT_POSTFIELDSIZE, @as(c_long, @intCast(body.len)));
        }

        // Headers (slist is stored in ctx and freed via slist_free_all in deinit)
        // Note: curl_slist_append copies the strings, so we can free header_z after append
        for (request.headers) |header| {
            const header_str = try std.fmt.allocPrint(ctx.allocator, "{s}: {s}", .{ header.name, header.value });
            defer ctx.allocator.free(header_str);
            const header_z = try ctx.allocator.dupeZ(u8, header_str);
            defer ctx.allocator.free(header_z);
            ctx.header_list = curl.slist_append(ctx.header_list, header_z.ptr);
        }
        if (ctx.header_list != null) {
            _ = curl.easy_setopt(handle, curl.CURLOPT_HTTPHEADER, ctx.header_list);
        }

        // HTTP version
        const curl_http_version: c_long = switch (request.http_version) {
            .http_1_0 => curl.CURL_HTTP_VERSION_1_0,
            .http_1_1 => curl.CURL_HTTP_VERSION_1_1,
            .http_2 => curl.CURL_HTTP_VERSION_2_0,
            .http_3 => curl.CURL_HTTP_VERSION_3,
        };
        _ = curl.easy_setopt(handle, curl.CURLOPT_HTTP_VERSION, curl_http_version);

        // Connection reuse is handled via global curl share (CURLOPT_SHARE)
        // set in sendImpl(). This allows connections to be pooled and reused
        // across requests, preventing socket exhaustion.

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
