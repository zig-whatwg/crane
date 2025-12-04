//! Network Backend Adapter
//!
//! Provides adapters between the old NetworkBackend interface and the new
//! unified NetworkVTable (C ABI compatible) interface.
//!
//! ## Migration Path
//!
//! 1. Existing code uses `NetworkBackend` (Zig-native VTable) in src/fetch/network/backend.zig
//! 2. New embedders implement `NetworkVTable` (C ABI compatible)
//! 3. Adapters bridge between the two interfaces
//!
//! ## Design Notes
//!
//! The NetworkVTable uses async callbacks while NetworkBackend is synchronous.
//! The adapter handles this by:
//! - For VTable -> Backend: Blocking until callback is received (via condition variable or busy wait)
//! - For Backend -> VTable: Immediately invoking callbacks with the synchronous result

const std = @import("std");
const Allocator = std.mem.Allocator;

const vtables = @import("vtables.zig");
const NetworkVTable = vtables.NetworkVTable;
const NetworkResult = vtables.NetworkResult;
const CNetworkRequest = vtables.CNetworkRequest;
const CHeader = vtables.CHeader;
const HttpMethod = vtables.HttpMethod;
const NetworkRequestHandle = vtables.NetworkRequestHandle;
const NetworkResponseCallback = vtables.NetworkResponseCallback;
const NetworkErrorCallback = vtables.NetworkErrorCallback;
const OpaquePtr = vtables.OpaquePtr;

// Import from fetch module (must be added as dependency in build.zig)
const fetch = @import("fetch");
const network_backend = fetch.network.backend;
const NetworkBackend = network_backend.NetworkBackend;
const OldNetworkRequest = network_backend.NetworkRequest;
const OldNetworkResponse = network_backend.NetworkResponse;
const OldNetworkError = network_backend.NetworkError;

// =============================================================================
// NetworkVTable -> NetworkBackend Adapter
// =============================================================================

/// Adapter that wraps a NetworkVTable and provides a NetworkBackend interface.
///
/// This allows new C ABI embedder implementations to be used with existing
/// Zig code that expects a NetworkBackend.
///
/// Note: Since NetworkVTable is async (callback-based) and NetworkBackend is sync,
/// this adapter blocks until the callback is received.
pub const NetworkBackendAdapter = struct {
    /// The wrapped VTable
    vtable: *const NetworkVTable,
    /// User context passed to VTable functions
    user_context: OpaquePtr,
    /// Allocator for internal operations
    allocator: Allocator,
    /// Current request handle for abort
    current_handle: NetworkRequestHandle,
    /// Flag to track abort state
    aborted: bool,

    const Self = @This();

    /// Create an adapter from a NetworkVTable.
    pub fn init(
        allocator: Allocator,
        vtable: *const NetworkVTable,
        user_context: OpaquePtr,
    ) !*Self {
        const self = try allocator.create(Self);
        self.* = Self{
            .vtable = vtable,
            .user_context = user_context,
            .allocator = allocator,
            .current_handle = 0,
            .aborted = false,
        };
        return self;
    }

    /// Get a NetworkBackend interface.
    pub fn backend(self: *Self) NetworkBackend {
        return NetworkBackend{
            .ptr = self,
            .vtable = &backend_vtable,
        };
    }

    pub fn deinit(self: *Self) void {
        self.allocator.destroy(self);
    }

    const backend_vtable = NetworkBackend.VTable{
        .send = sendImpl,
        .abort = abortImpl,
        .supportsStreaming = supportsStreamingImpl,
        .getName = getNameImpl,
        .deinit = deinitImpl,
    };

    /// Context for callback synchronization
    const CallbackContext = struct {
        completed: bool,
        response: ?OldNetworkResponse,
        err: ?OldNetworkError,
        allocator: Allocator,
    };

    fn sendImpl(ptr: *anyopaque, allocator: Allocator, request: *const OldNetworkRequest) OldNetworkError!OldNetworkResponse {
        const self: *Self = @ptrCast(@alignCast(ptr));

        if (self.aborted) {
            return OldNetworkError.Aborted;
        }

        // Convert headers to C format
        var c_headers: []CHeader = &.{};
        if (request.headers.len > 0) {
            c_headers = allocator.alloc(CHeader, request.headers.len) catch return OldNetworkError.OutOfMemory;
            for (request.headers, 0..) |h, i| {
                c_headers[i] = CHeader{
                    .name = h.name.ptr,
                    .nameLen = h.name.len,
                    .value = h.value.ptr,
                    .valueLen = h.value.len,
                };
            }
        }
        defer if (c_headers.len > 0) allocator.free(c_headers);

        // Convert method string to enum
        const method = methodFromString(request.method);

        // Build C request
        const c_request = CNetworkRequest{
            .url = request.url.ptr,
            .url_len = request.url.len,
            .method = method,
            .headers = if (c_headers.len > 0) c_headers.ptr else null,
            .headersCount = c_headers.len,
            .body = if (request.body) |b| b.ptr else null,
            .bodyLen = if (request.body) |b| b.len else 0,
            .timeout_ms = request.timeout_ms,
            .followRedirects = request.follow_redirects,
        };

        // Set up callback context
        var ctx = CallbackContext{
            .completed = false,
            .response = null,
            .err = null,
            .allocator = allocator,
        };

        // Make the request
        self.current_handle = self.vtable.call_fetch(
            self.user_context,
            &c_request,
            responseCallback,
            errorCallback,
            &ctx,
        );

        // Wait for completion (busy wait - in real implementation would use condition variable)
        while (!ctx.completed) {
            // In a real implementation, this would yield to an event loop
            // For now, we assume the callback is called synchronously or very quickly
            std.time.sleep(1_000_000); // 1ms
        }

        // Return result
        if (ctx.err) |err| {
            return err;
        }

        return ctx.response orelse OldNetworkError.Unknown;
    }

    fn responseCallback(
        userData: OpaquePtr,
        status: u16,
        headers: [*]const CHeader,
        headersCount: usize,
        body: [*]const u8,
        bodyLen: usize,
    ) callconv(.c) void {
        const ctx: *CallbackContext = @ptrCast(@alignCast(userData));

        // Build response
        const response_headers = ctx.allocator.alloc(OldNetworkResponse.Header, headersCount) catch {
            ctx.err = OldNetworkError.OutOfMemory;
            ctx.completed = true;
            return;
        };

        for (0..headersCount) |i| {
            response_headers[i] = .{
                .name = ctx.allocator.dupe(u8, headers[i].name[0..headers[i].nameLen]) catch {
                    // Clean up partial allocation
                    for (0..i) |j| {
                        ctx.allocator.free(response_headers[j].name);
                        ctx.allocator.free(response_headers[j].value);
                    }
                    ctx.allocator.free(response_headers);
                    ctx.err = OldNetworkError.OutOfMemory;
                    ctx.completed = true;
                    return;
                },
                .value = ctx.allocator.dupe(u8, headers[i].value[0..headers[i].valueLen]) catch {
                    // Clean up partial allocation
                    ctx.allocator.free(response_headers[i].name);
                    for (0..i) |j| {
                        ctx.allocator.free(response_headers[j].name);
                        ctx.allocator.free(response_headers[j].value);
                    }
                    ctx.allocator.free(response_headers);
                    ctx.err = OldNetworkError.OutOfMemory;
                    ctx.completed = true;
                    return;
                },
            };
        }

        ctx.response = OldNetworkResponse{
            .allocator = ctx.allocator,
            .status = status,
            .http_version = .http_1_1,
            .headers = response_headers,
            .body = if (bodyLen > 0) ctx.allocator.dupe(u8, body[0..bodyLen]) catch null else null,
            .final_url = null,
            .total_time_ms = 0,
            .time_to_first_byte_ms = 0,
            .redirect_count = 0,
            .remote_ip = null,
            .remote_port = null,
        };
        ctx.completed = true;
    }

    fn errorCallback(userData: OpaquePtr, result: NetworkResult) callconv(.c) void {
        const ctx: *CallbackContext = @ptrCast(@alignCast(userData));
        ctx.err = convertNetworkResult(result);
        ctx.completed = true;
    }

    fn abortImpl(ptr: *anyopaque) void {
        const self: *Self = @ptrCast(@alignCast(ptr));
        self.aborted = true;
        if (self.current_handle != 0) {
            self.vtable.call_abort(self.user_context, self.current_handle);
        }
    }

    fn supportsStreamingImpl(_: *anyopaque) bool {
        return false; // C ABI adapter doesn't support streaming
    }

    fn getNameImpl(_: *anyopaque) []const u8 {
        return "NetworkVTableAdapter";
    }

    fn deinitImpl(ptr: *anyopaque) void {
        const self: *Self = @ptrCast(@alignCast(ptr));
        self.deinit();
    }

    fn methodFromString(method: []const u8) HttpMethod {
        if (std.mem.eql(u8, method, "GET")) return .GET;
        if (std.mem.eql(u8, method, "POST")) return .POST;
        if (std.mem.eql(u8, method, "PUT")) return .PUT;
        if (std.mem.eql(u8, method, "DELETE")) return .DELETE;
        if (std.mem.eql(u8, method, "HEAD")) return .HEAD;
        if (std.mem.eql(u8, method, "OPTIONS")) return .OPTIONS;
        if (std.mem.eql(u8, method, "PATCH")) return .PATCH;
        if (std.mem.eql(u8, method, "CONNECT")) return .CONNECT;
        if (std.mem.eql(u8, method, "TRACE")) return .TRACE;
        return .GET;
    }

    fn convertNetworkResult(result: NetworkResult) OldNetworkError {
        return switch (result) {
            .success => OldNetworkError.Unknown, // Success shouldn't call error callback
            .dns_failed => OldNetworkError.DnsResolutionFailed,
            .connection_refused => OldNetworkError.ConnectionRefused,
            .connection_timeout => OldNetworkError.ConnectionTimeout,
            .request_timeout => OldNetworkError.RequestTimeout,
            .ssl_error => OldNetworkError.SslHandshakeFailed,
            .too_many_redirects => OldNetworkError.TooManyRedirects,
            .invalid_url => OldNetworkError.InvalidUrl,
            .aborted => OldNetworkError.Aborted,
            .network_error => OldNetworkError.Unknown,
        };
    }
};

// =============================================================================
// NetworkBackend -> NetworkVTable Adapter
// =============================================================================

/// Context for NetworkVTable that wraps a NetworkBackend.
///
/// This allows existing Zig NetworkBackend implementations (like MockBackend)
/// to be used with the new unified PlatformBackend system.
pub const NetworkVTableAdapter = struct {
    /// The wrapped backend
    wrapped_backend: NetworkBackend,
    /// Allocator for operations
    allocator: Allocator,
    /// Next request handle
    next_handle: NetworkRequestHandle,
    /// Online status (defaults to true)
    online: bool,

    const Self = @This();

    /// Create an adapter context.
    pub fn init(allocator: Allocator, wrapped_backend: NetworkBackend) !*Self {
        const self = try allocator.create(Self);
        self.* = Self{
            .wrapped_backend = wrapped_backend,
            .allocator = allocator,
            .next_handle = 1,
            .online = true,
        };
        return self;
    }

    pub fn deinit(self: *Self) void {
        self.allocator.destroy(self);
    }

    /// Set online status (for navigator.onLine)
    pub fn setOnline(self: *Self, online: bool) void {
        self.online = online;
    }

    /// Get a pointer to the static VTable.
    pub fn getVTable() *const NetworkVTable {
        return &c_vtable;
    }

    /// Get the user context pointer (pass this to PlatformBackend).
    pub fn getUserContext(self: *Self) OpaquePtr {
        return self;
    }

    const c_vtable = NetworkVTable{
        .call_fetch = fetchImpl,
        .call_abort = abortImpl,
        .get_onLine = onLineImpl,
    };

    fn fetchImpl(
        user_context: OpaquePtr,
        request: *const CNetworkRequest,
        onResponse: NetworkResponseCallback,
        onError: NetworkErrorCallback,
        callbackUserData: OpaquePtr,
    ) callconv(.c) NetworkRequestHandle {
        const self: *Self = @ptrCast(@alignCast(user_context));

        // Convert C request to Zig request
        const headers = if (request.headers != null and request.headersCount > 0)
            self.allocator.alloc(OldNetworkRequest.Header, request.headersCount) catch {
                onError(callbackUserData, .network_error);
                return 0;
            }
        else
            &[_]OldNetworkRequest.Header{};

        if (request.headers != null and request.headersCount > 0) {
            for (0..request.headersCount) |i| {
                const h = request.headers.?[i];
                headers[i] = .{
                    .name = self.allocator.dupe(u8, h.name[0..h.nameLen]) catch {
                        onError(callbackUserData, .network_error);
                        return 0;
                    },
                    .value = self.allocator.dupe(u8, h.value[0..h.valueLen]) catch {
                        onError(callbackUserData, .network_error);
                        return 0;
                    },
                };
            }
        }
        defer {
            for (headers) |h| {
                self.allocator.free(h.name);
                self.allocator.free(h.value);
            }
            if (headers.len > 0) self.allocator.free(headers);
        }

        const zig_request = OldNetworkRequest{
            .url = request.url[0..request.url_len],
            .method = methodToString(request.method),
            .headers = headers,
            .body = if (request.body != null and request.bodyLen > 0)
                request.body.?[0..request.bodyLen]
            else
                null,
            .timeout_ms = request.timeout_ms,
            .follow_redirects = request.followRedirects,
        };

        // Call the wrapped backend
        const response = self.wrapped_backend.send(self.allocator, &zig_request) catch |err| {
            onError(callbackUserData, convertOldError(err));
            return 0;
        };

        // Convert response headers to C format
        const c_headers = self.allocator.alloc(CHeader, response.headers.len) catch {
            var mutable_response = response;
            mutable_response.deinit();
            onError(callbackUserData, .network_error);
            return 0;
        };
        defer self.allocator.free(c_headers);

        for (response.headers, 0..) |h, i| {
            c_headers[i] = CHeader{
                .name = h.name.ptr,
                .nameLen = h.name.len,
                .value = h.value.ptr,
                .valueLen = h.value.len,
            };
        }

        // Call success callback
        onResponse(
            callbackUserData,
            response.status,
            c_headers.ptr,
            c_headers.len,
            if (response.body) |b| b.ptr else @as([*]const u8, ""),
            if (response.body) |b| b.len else 0,
        );

        // Clean up response
        var mutable_response = response;
        mutable_response.deinit();

        // Return handle
        const handle = self.next_handle;
        self.next_handle += 1;
        return handle;
    }

    fn abortImpl(user_context: OpaquePtr, _: NetworkRequestHandle) callconv(.c) void {
        const self: *Self = @ptrCast(@alignCast(user_context));
        self.wrapped_backend.abort();
    }

    fn onLineImpl(user_context: OpaquePtr) callconv(.c) bool {
        const self: *Self = @ptrCast(@alignCast(user_context));
        return self.online;
    }

    fn methodToString(method: HttpMethod) []const u8 {
        return switch (method) {
            .GET => "GET",
            .POST => "POST",
            .PUT => "PUT",
            .DELETE => "DELETE",
            .HEAD => "HEAD",
            .OPTIONS => "OPTIONS",
            .PATCH => "PATCH",
            .CONNECT => "CONNECT",
            .TRACE => "TRACE",
        };
    }

    fn convertOldError(err: OldNetworkError) NetworkResult {
        return switch (err) {
            OldNetworkError.DnsResolutionFailed => .dns_failed,
            OldNetworkError.ConnectionRefused => .connection_refused,
            OldNetworkError.ConnectionTimeout => .connection_timeout,
            OldNetworkError.RequestTimeout => .request_timeout,
            OldNetworkError.SslHandshakeFailed, OldNetworkError.SslCertificateError => .ssl_error,
            OldNetworkError.TooManyRedirects => .too_many_redirects,
            OldNetworkError.InvalidUrl => .invalid_url,
            OldNetworkError.Aborted => .aborted,
            else => .network_error,
        };
    }
};

// =============================================================================
// Convenience Functions
// =============================================================================

/// Create a NetworkVTable adapter from a MockBackend.
///
/// This is a common use case for testing.
pub fn createMockVTableAdapter(
    allocator: Allocator,
    mock: *network_backend.MockBackend,
) !*NetworkVTableAdapter {
    return NetworkVTableAdapter.init(allocator, mock.backend());
}

// =============================================================================
// Tests
// =============================================================================

test "NetworkVTableAdapter - wraps MockBackend" {
    const allocator = std.testing.allocator;

    // Create mock backend
    const mock = network_backend.MockBackend.init(allocator);
    defer mock.deinit();

    // Add a canned response
    try mock.addResponse("https://example.com/api", .{
        .status = 200,
        .headers = &.{
            .{ .name = "Content-Type", .value = "application/json" },
        },
        .body = "{\"ok\": true}",
    });

    // Create adapter
    const adapter = try NetworkVTableAdapter.init(allocator, mock.backend());
    defer adapter.deinit();

    // Get VTable
    const vtable = NetworkVTableAdapter.getVTable();
    const ctx = adapter.getUserContext();

    // Test online status
    try std.testing.expect(vtable.get_onLine(ctx));

    // Test request
    const TestContext = struct {
        response_received: bool = false,
        error_received: bool = false,
        status: u16 = 0,
        body_len: usize = 0,
    };
    var test_ctx = TestContext{};

    const c_request = CNetworkRequest{
        .url = "https://example.com/api",
        .url_len = 23,
        .method = .GET,
        .headers = null,
        .headersCount = 0,
        .body = null,
        .bodyLen = 0,
        .timeout_ms = 30000,
        .followRedirects = true,
    };

    const onResponse = struct {
        fn callback(
            userData: OpaquePtr,
            status: u16,
            _: [*]const CHeader,
            _: usize,
            _: [*]const u8,
            bodyLen: usize,
        ) callconv(.c) void {
            const tctx: *TestContext = @ptrCast(@alignCast(userData));
            tctx.response_received = true;
            tctx.status = status;
            tctx.body_len = bodyLen;
        }
    }.callback;

    const onError = struct {
        fn callback(userData: OpaquePtr, _: NetworkResult) callconv(.c) void {
            const tctx: *TestContext = @ptrCast(@alignCast(userData));
            tctx.error_received = true;
        }
    }.callback;

    const handle = vtable.call_fetch(ctx, &c_request, onResponse, onError, &test_ctx);

    try std.testing.expect(handle != 0);
    try std.testing.expect(test_ctx.response_received);
    try std.testing.expect(!test_ctx.error_received);
    try std.testing.expectEqual(@as(u16, 200), test_ctx.status);
    try std.testing.expect(test_ctx.body_len > 0);
}

test "NetworkVTableAdapter - error handling" {
    const allocator = std.testing.allocator;

    const mock = network_backend.MockBackend.init(allocator);
    defer mock.deinit();

    // Force error
    mock.setForceError(OldNetworkError.ConnectionRefused);

    const adapter = try NetworkVTableAdapter.init(allocator, mock.backend());
    defer adapter.deinit();

    const vtable = NetworkVTableAdapter.getVTable();
    const ctx = adapter.getUserContext();

    const TestContext = struct {
        response_received: bool = false,
        error_received: bool = false,
        error_result: NetworkResult = .success,
    };
    var test_ctx = TestContext{};

    const c_request = CNetworkRequest{
        .url = "https://example.com/fail",
        .url_len = 24,
        .method = .GET,
        .headers = null,
        .headersCount = 0,
        .body = null,
        .bodyLen = 0,
        .timeout_ms = 30000,
        .followRedirects = true,
    };

    const onResponse = struct {
        fn callback(
            userData: OpaquePtr,
            _: u16,
            _: [*]const CHeader,
            _: usize,
            _: [*]const u8,
            _: usize,
        ) callconv(.c) void {
            const tctx: *TestContext = @ptrCast(@alignCast(userData));
            tctx.response_received = true;
        }
    }.callback;

    const onError = struct {
        fn callback(userData: OpaquePtr, result: NetworkResult) callconv(.c) void {
            const tctx: *TestContext = @ptrCast(@alignCast(userData));
            tctx.error_received = true;
            tctx.error_result = result;
        }
    }.callback;

    _ = vtable.call_fetch(ctx, &c_request, onResponse, onError, &test_ctx);

    try std.testing.expect(!test_ctx.response_received);
    try std.testing.expect(test_ctx.error_received);
    try std.testing.expectEqual(NetworkResult.connection_refused, test_ctx.error_result);
}

test "NetworkVTableAdapter - set online status" {
    const allocator = std.testing.allocator;

    const mock = network_backend.MockBackend.init(allocator);
    defer mock.deinit();

    const adapter = try NetworkVTableAdapter.init(allocator, mock.backend());
    defer adapter.deinit();

    const vtable = NetworkVTableAdapter.getVTable();
    const ctx = adapter.getUserContext();

    // Default is online
    try std.testing.expect(vtable.get_onLine(ctx));

    // Set offline
    adapter.setOnline(false);
    try std.testing.expect(!vtable.get_onLine(ctx));

    // Set back online
    adapter.setOnline(true);
    try std.testing.expect(vtable.get_onLine(ctx));
}
