//! Implementation for WindowOrWorkerGlobalScope interface
//!
//! This mixin provides common functionality shared between Window and Worker global scopes.
//! The fetch() method implemented here can be used by any global scope that includes
//! this mixin.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const WindowOrWorkerGlobalScope = interfaces.WindowOrWorkerGlobalScope;

// Fetch API support
const fetch_api = @import("fetch");
const global_fetch = fetch_api.webidl.global_fetch;
const ResponseImpl = @import("Response.zig");

// Async network support
const network = fetch_api.network;
const AsyncCurlManager = network.AsyncCurlManager;
const NetworkRequest = network.NetworkRequest;
const AsyncResult = network.AsyncResult;

// Body extraction support
const BlobImpl = @import("Blob.zig");
const URLSearchParamsImpl = @import("URLSearchParams.zig");

// Form serialization for URLSearchParams body
const form_serializer = @import("form_serializer");

// Environment settings for origin access
const environment_settings = runtime.environment_settings;
const Origin = environment_settings.Origin;

pub const State = WindowOrWorkerGlobalScope.State;

pub const ImplError = error{
    NotImplemented,
};

// ============================================================================
// CORS Support - Origin Detection
// ============================================================================

/// Extract origin from a URL string (scheme://host:port)
/// Returns null if URL is malformed.
fn extractOrigin(url: []const u8) ?[]const u8 {
    // Find scheme separator
    const scheme_end = std.mem.indexOf(u8, url, "://") orelse return null;

    // Find path start (after host)
    const after_scheme = url[scheme_end + 3 ..];
    const path_start = std.mem.indexOf(u8, after_scheme, "/");

    if (path_start) |ps| {
        return url[0 .. scheme_end + 3 + ps];
    } else {
        return url;
    }
}

/// Check if a request URL is cross-origin relative to the document's origin.
/// Cross-origin means different scheme, host, or port.
fn isCrossOrigin(document_origin: ?[]const u8, request_url: []const u8) bool {
    const doc_origin = document_origin orelse return true;
    const req_origin = extractOrigin(request_url) orelse return true;

    return !std.mem.eql(u8, doc_origin, req_origin);
}

/// Get the document's origin string from the context.
/// Returns null if origin cannot be determined.
fn getDocumentOrigin(ctx: runtime.Context, allocator: std.mem.Allocator) ?[]const u8 {
    _ = ctx;
    _ = allocator;
    // TODO: Implement proper origin extraction from environment settings
    // For now, return null - cross-origin detection will be skipped
    // This is acceptable for initial implementation as the Origin header
    // will fall back to the request URL origin
    return null;
}

// ============================================================================
// Async Fetch Support
// ============================================================================

/// Context for async fetch completion callback.
/// Holds the V8 promise handle and engine context needed to resolve/reject.
const FetchCompletionContext = struct {
    /// Promise handle to resolve/reject
    promise_handle: *anyopaque,
    /// Allocator for cleanup
    allocator: std.mem.Allocator,
    /// Engine interface for V8 operations
    engine: *const runtime.EngineInterface,
    /// Engine context (V8 context pointer)
    engine_ctx: *anyopaque,
    /// Runtime context for creating Response instance
    runtime_ctx: runtime.Context,

    fn deinit(self: *FetchCompletionContext) void {
        // Destroy promise handle
        if (self.engine.destroyPromiseHandle) |destroy| {
            destroy(self.promise_handle, self.allocator);
        }
        self.allocator.destroy(self);
    }
};

/// Completion callback invoked when async fetch completes.
/// This runs on the event loop thread when the HTTP response arrives.
fn asyncFetchCompletionCallback(result: AsyncResult, user_data: ?*anyopaque) void {
    const ctx: *FetchCompletionContext = @ptrCast(@alignCast(user_data orelse return));

    switch (result) {
        .success => |response| {
            std.debug.print("[Fetch] Async SUCCESS - status: {d}\n", .{response.status});
            // Create a WebIDL Response instance wrapping the NetworkResponse
            const response_instance = ResponseImpl.initWithNetworkResponse(
                ctx.allocator,
                ctx.runtime_ctx,
                response,
            ) catch |err| {
                // Failed to create Response object - reject Promise
                ctx.engine.rejectPromise(ctx.engine_ctx, ctx.promise_handle, err) catch {};
                ctx.deinit();
                return;
            };

            // Wrap the Response instance as a V8 object
            const wrapInstance = ctx.engine.wrapInstance orelse {
                ctx.engine.rejectPromise(ctx.engine_ctx, ctx.promise_handle, error.InvalidState) catch {};
                ctx.deinit();
                return;
            };

            const js_response = wrapInstance(ctx.engine_ctx, response_instance) catch {
                ctx.engine.rejectPromise(ctx.engine_ctx, ctx.promise_handle, error.InvalidState) catch {};
                ctx.deinit();
                return;
            };

            // Resolve the promise with the JS Response object
            ctx.engine.resolvePromise(ctx.engine_ctx, ctx.promise_handle, js_response) catch {};
        },
        .failure => |net_error| {
            // Log the network error with category for debugging
            const category = switch (net_error) {
                error.Aborted => "ABORTED",
                error.ConnectionRefused, error.ConnectionReset, error.ConnectionTimeout => "CONNECTION",
                error.DnsResolutionFailed, error.HostUnreachable, error.NetworkUnreachable => "NETWORK",
                error.InvalidUrl => "URL_FORMAT",
                error.RequestTimeout => "TIMEOUT",
                error.SslCertificateError, error.SslHandshakeFailed => "TLS",
                error.TooManyRedirects => "REDIRECT",
                error.ProtocolError => "PROTOCOL/CONFIG",
                error.OutOfMemory => "MEMORY",
                error.Unknown => "UNKNOWN",
            };
            std.debug.print("[Fetch] Async FAILURE: {s} (category: {s})\n", .{ @errorName(net_error), category });

            // Map network error to fetch error per WHATWG Fetch spec
            // Spec: https://fetch.spec.whatwg.org/#concept-network-error
            const fetch_error: anyerror = switch (net_error) {
                // AbortError: fetch was aborted by user/signal
                error.Aborted => error.AbortError,
                // NetworkError: general network failures (connection, DNS, TLS)
                error.ConnectionRefused, error.ConnectionReset, error.ConnectionTimeout => error.NetworkError,
                error.DnsResolutionFailed, error.HostUnreachable, error.NetworkUnreachable => error.NetworkError,
                error.RequestTimeout => error.NetworkError,
                error.SslCertificateError, error.SslHandshakeFailed => error.NetworkError,
                error.TooManyRedirects => error.NetworkError,
                // TypeError: malformed URL (spec says reject with TypeError for bad URLs)
                error.InvalidUrl => error.TypeError,
                // ProtocolError: could be config issue (bad params) or protocol mismatch
                // Map to NetworkError since it's a network-level issue
                error.ProtocolError => error.NetworkError,
                // OutOfMemory: propagate as-is
                error.OutOfMemory => error.OutOfMemory,
                // Unknown: catch-all for unexpected errors
                error.Unknown => error.NetworkError,
            };
            std.debug.print("[Fetch] Rejecting with: {s}\n", .{@errorName(fetch_error)});
            ctx.engine.rejectPromise(ctx.engine_ctx, ctx.promise_handle, fetch_error) catch {};
        },
    }

    ctx.deinit();
}

/// Internal state for implementation-specific data
/// Implementations can replace this with a real struct containing:
/// - Private data not exposed via WebIDL attributes
/// - Cached computations, buffers, etc.
pub const InternalState = struct {};

/// Initialize instance (creates the instance)
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    const instance = try runtime.Instance.init(allocator, StateType, vtable, ctx);
    // TODO: Initialize your instance state here if needed
    return instance;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    // TODO: Clean up your instance resources here
    _ = instance; // GC layer handles slab freeing - do NOT call runtime.Instance.deinit()
}

/// Getter for origin
pub fn get_origin(instance: *runtime.Instance) anyerror!runtime.USVString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for isSecureContext
pub fn get_isSecureContext(instance: *runtime.Instance) anyerror!bool {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for crossOriginIsolated
pub fn get_crossOriginIsolated(instance: *runtime.Instance) anyerror!bool {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for indexedDB
pub fn get_indexedDB(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for trustedTypes
pub fn get_trustedTypes(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for performance
pub fn get_performance(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for caches
pub fn get_caches(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for scheduler
pub fn get_scheduler(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for crypto
pub fn get_crypto(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: reportError
pub fn call_reportError(instance: *runtime.Instance, e: runtime.JSValue) anyerror!void {
    _ = instance;
    _ = e;
    return error.NotImplemented;
}

/// Operation: setInterval
/// Spec: https://html.spec.whatwg.org/multipage/timers-and-user-prompts.html#dom-setinterval
///
/// TODO: When implementing, the handler MUST be stored as a V8 Global handle
/// if handler.function is a JavaScript callback. See:
/// - tmp/analysis/CALLBACK_STORAGE.md for the pattern
/// - src/webidl/impls/WebSocket.zig for example usage of OptionalGlobalHandle
///
/// Implementation requirements:
/// 1. For handler.function variant, create Global handle
/// 2. Store in interval registry with Global handle
/// 3. Dispose Global handle when interval is cleared via clearInterval
/// 4. Handle repeating invocation pattern
pub fn call_setInterval(instance: *runtime.Instance, handler: typedefs.TimerHandler, timeout: webidl.Opt(i32), arguments: []const runtime.JSValue) anyerror!i32 {
    _ = instance;
    _ = handler;
    _ = timeout;
    _ = arguments;
    return error.NotImplemented;
}

/// Operation: atob
pub fn call_atob(instance: *runtime.Instance, data: runtime.DOMString) anyerror!runtime.ByteString {
    _ = instance;
    _ = data;
    return error.NotImplemented;
}

/// Operation: btoa
pub fn call_btoa(instance: *runtime.Instance, data: runtime.DOMString) anyerror!runtime.DOMString {
    _ = instance;
    _ = data;
    return error.NotImplemented;
}

/// Operation: createImageBitmap
pub fn call_createImageBitmap(instance: *runtime.Instance, image: typedefs.ImageBitmapSource, options: webidl.Opt(dictionaries.ImageBitmapOptions)) anyerror!runtime.JSValue {
    _ = instance;
    _ = image;
    _ = options;
    return error.NotImplemented;
}

/// Operation: clearInterval
pub fn call_clearInterval(instance: *runtime.Instance, id: webidl.Opt(i32)) anyerror!void {
    _ = instance;
    _ = id;
    return error.NotImplemented;
}

/// Operation: queueMicrotask
/// Spec: https://html.spec.whatwg.org/multipage/timers-and-user-prompts.html#dom-queuemicrotask
///
/// TODO: When implementing, the callback MUST be stored as a V8 Global handle.
/// Unlike setTimeout/setInterval, microtasks execute on the current event loop turn
/// but still need Global handles since the callback must survive the caller's HandleScope.
///
/// Implementation requirements:
/// 1. Create Global handle for the VoidFunction callback
/// 2. Queue in microtask queue
/// 3. Dispose Global handle after callback executes
pub fn call_queueMicrotask(instance: *runtime.Instance, callback: callbacks.VoidFunction) anyerror!void {
    _ = instance;
    _ = callback;
    return error.NotImplemented;
}

/// Operation: structuredClone
pub fn call_structuredClone(instance: *runtime.Instance, value: runtime.JSValue, options: webidl.Opt(dictionaries.StructuredSerializeOptions)) anyerror!runtime.JSValue {
    _ = instance;
    _ = value;
    _ = options;
    return error.NotImplemented;
}

/// Operation: setTimeout
/// Spec: https://html.spec.whatwg.org/multipage/timers-and-user-prompts.html#dom-settimeout
///
/// TODO: When implementing, the handler MUST be stored as a V8 Global handle
/// if handler.function is a JavaScript callback. See:
/// - tmp/analysis/CALLBACK_STORAGE.md for the pattern
/// - src/webidl/impls/WebSocket.zig for example usage of OptionalGlobalHandle
///
/// Implementation requirements:
/// 1. For handler.function variant, create Global handle
/// 2. Store in timer registry with Global handle
/// 3. Dispose Global handle when timer fires or is cleared via clearTimeout
/// 4. Handle one-shot invocation (unlike setInterval)
pub fn call_setTimeout(instance: *runtime.Instance, handler: typedefs.TimerHandler, timeout: webidl.Opt(i32), arguments: []const runtime.JSValue) anyerror!i32 {
    _ = instance;
    _ = handler;
    _ = timeout;
    _ = arguments;
    return error.NotImplemented;
}

/// Operation: clearTimeout
pub fn call_clearTimeout(instance: *runtime.Instance, id: webidl.Opt(i32)) anyerror!void {
    _ = instance;
    _ = id;
    return error.NotImplemented;
}

/// Operation: fetch
/// Implements the global fetch() function per WHATWG Fetch Standard.
/// Spec: https://fetch.spec.whatwg.org/#fetch-method
///
/// This is the mixin implementation used by Window and WorkerGlobalScope.
/// Implementation notes:
/// - Extracts URL from RequestInfo (string or Request object)
/// - Applies RequestInit options (method, headers, body, mode, credentials, etc.)
/// - Returns a Promise that resolves to a Response object
/// - Currently synchronous (blocking) - true async requires libuv event loop integration
pub fn call_fetch(instance: *runtime.Instance, input: typedefs.RequestInfo, init_data: webidl.Opt(dictionaries.RequestInit)) anyerror!runtime.JSValue {
    const allocator = instance.ctx.allocator;

    // Create headers list for network request
    // These will be converted from HeadersInit and passed to NetworkRequest
    var headers_list: std.ArrayList(NetworkRequest.Header) = .{};
    defer headers_list.deinit(allocator);

    // Track the method string (default to GET)
    var request_method: []const u8 = "GET";

    // Get the engine interface and context
    const engine = instance.ctx.engine orelse {
        return error.InvalidStateError;
    };
    const engine_ctx = instance.ctx.engine_ctx orelse {
        return error.InvalidStateError;
    };

    // Create a Promise to return to JavaScript
    const promise_handle = engine.createPromise(engine_ctx, allocator) catch {
        return error.OutOfMemory;
    };

    // Extract URL from input (RequestInfo is USVString or Request)
    const url_str: []const u8 = switch (input) {
        .usvstring => |s| blk: {
            std.debug.print("[Fetch] Input URL from string: {s}\n", .{s});
            break :blk s;
        },
        .request => |req_instance| blk: {
            // Check if this is actually a Request instance by trying to get its URL.
            // If the object is a URL or other stringifiable object incorrectly classified
            // as a Request (because it's a WebIDL interface), we need to convert it to string.
            //
            // First, try to get URL from Request instance
            if (interfaces.Request.get_url(req_instance)) |req_url| {
                std.debug.print("[Fetch] Input URL from Request: {s}\n", .{req_url});
                break :blk req_url;
            } else |_| {
                // Not a valid Request - try to get URL from URL interface
                // The URL interface has a get_href method that returns the full URL string
                if (interfaces.URL.get_href(req_instance)) |url_href| {
                    std.debug.print("[Fetch] Input URL from URL object: {s}\n", .{url_href});
                    break :blk url_href;
                } else |_| {
                    // Neither Request nor URL - this is an error
                    std.debug.print("[Fetch] Object is neither Request nor URL\n", .{});
                    engine.rejectPromise(engine_ctx, promise_handle, error.TypeError) catch {};
                    return getPromiseAndCleanup(engine, promise_handle, allocator);
                }
            }
        },
    };

    // Build RequestInit options for the internal fetch
    var request_init = fetch_api.webidl.request.RequestInit{};

    // Apply RequestInit options if provided
    if (init_data.wasPassed()) {
        const init_opts = init_data.getValue();

        // Method
        if (init_opts.method) |method| {
            request_init.method = method;
            request_method = method;
        }

        // Headers - convert from HeadersInit to internal format
        // HeadersInit can be sequence<sequence<ByteString>> or record<ByteString, ByteString>
        if (init_opts.headers) |headers_init| {
            switch (headers_init) {
                .sequence_byte_string_sequence => |seq| {
                    // Each inner sequence should have 2 elements: [name, value]
                    for (seq) |header_pair| {
                        if (header_pair.len >= 2) {
                            try headers_list.append(allocator, .{
                                .name = header_pair[0],
                                .value = header_pair[1],
                            });
                        }
                    }
                },
                .byte_string_byte_string_record => |record| {
                    // Record is a slice of key-value structs
                    for (record) |entry| {
                        try headers_list.append(allocator, .{
                            .name = entry.key,
                            .value = entry.value,
                        });
                    }
                },
            }
        }

        // Body - convert from BodyInit to internal format
        // Spec: https://fetch.spec.whatwg.org/#bodyinit-safely-extract
        //
        // Content-Type defaults per spec:
        // - USVString: text/plain;charset=UTF-8
        // - Blob: Blob's type (if non-empty)
        // - BufferSource: (none)
        // - URLSearchParams: application/x-www-form-urlencoded;charset=UTF-8
        // - FormData: multipart/form-data; boundary=...
        // - ReadableStream: (none)
        if (init_opts.body) |body_init| {
            switch (body_init) {
                .xmlhttp_request_body_init => |xhr_body| {
                    switch (xhr_body) {
                        .usvstring => |s| {
                            // USVString body: duplicate for async lifetime
                            const body_bytes = allocator.dupe(u8, s) catch null;
                            if (body_bytes) |b| {
                                request_init.body = b;
                                // Set Content-Type if not already present
                                if (!headersListContains(headers_list.items, "Content-Type")) {
                                    headers_list.append(allocator, .{
                                        .name = "Content-Type",
                                        .value = "text/plain;charset=UTF-8",
                                    }) catch {};
                                }
                            }
                        },
                        .blob => |blob_instance| {
                            // Extract bytes from Blob's internal state
                            if (BlobImpl.getInternal(blob_instance)) |internal| {
                                // Duplicate bytes for async lifetime safety
                                const body_bytes = allocator.dupe(u8, internal.blob_data.bytes) catch null;
                                if (body_bytes) |b| {
                                    request_init.body = b;
                                    // Set Content-Type from blob's type if non-empty and not already set
                                    const blob_type = internal.blob_data.getType();
                                    if (blob_type.len > 0 and !headersListContains(headers_list.items, "Content-Type")) {
                                        headers_list.append(allocator, .{
                                            .name = "Content-Type",
                                            .value = blob_type,
                                        }) catch {};
                                    }
                                }
                            }
                        },
                        .buffer_source => |buffer_source| {
                            // Extract bytes from BufferSource (ArrayBuffer or ArrayBufferView)
                            const bytes = buffer_source.asBytes() catch null;
                            if (bytes) |b| {
                                // Duplicate bytes for async lifetime safety
                                const body_bytes = allocator.dupe(u8, b) catch null;
                                if (body_bytes) |duped| {
                                    request_init.body = duped;
                                    // No default Content-Type for BufferSource per spec
                                }
                            }
                        },
                        .urlsearch_params => |usp_instance| {
                            // Serialize URLSearchParams to application/x-www-form-urlencoded
                            // serialize() returns an allocated string, so it's already owned
                            const serialized = URLSearchParamsImpl.serialize(usp_instance) catch null;
                            if (serialized) |s| {
                                request_init.body = s;
                                // Set Content-Type if not already present
                                if (!headersListContains(headers_list.items, "Content-Type")) {
                                    headers_list.append(allocator, .{
                                        .name = "Content-Type",
                                        .value = "application/x-www-form-urlencoded;charset=UTF-8",
                                    }) catch {};
                                }
                            }
                        },
                        .form_data => {
                            // FormData requires multipart/form-data encoding
                            // TODO: Implement multipart encoding when FormData impl is complete
                            // Content-Type should be "multipart/form-data; boundary=..."
                        },
                    }
                },
                .readable_stream => {
                    // ReadableStream body requires async streaming
                    // TODO: Implement streaming body when async I/O is complete (whatwg-ij93j)
                    // This is complex: need to read chunks as they arrive and send to network
                },
            }
        }

        // Note: mode, referrer, referrerPolicy are applied below during
        // NetworkRequest construction (mode affects CORS, referrer affects headers)
    }

    // Extract RequestInit options for network configuration
    // Spec: https://fetch.spec.whatwg.org/#request-class
    var follow_redirects: bool = true; // Default: follow redirects

    if (init_data.wasPassed()) {
        const init_opts = init_data.getValue();

        // Redirect mode - controls how redirects are handled
        // Spec: https://fetch.spec.whatwg.org/#dom-requestinit-redirect
        if (init_opts.redirect) |redirect| {
            follow_redirects = switch (redirect) {
                ._follow_ => true, // Follow redirects automatically
                ._error_ => false, // Will error on redirect (TODO: handle in completion callback)
                ._manual_ => false, // Return opaque-redirect response (TODO: handle in callback)
            };
        }

        // Cache mode - add appropriate Cache-Control headers
        // Spec: https://fetch.spec.whatwg.org/#dom-requestinit-cache
        if (init_opts.cache) |cache_mode| {
            switch (cache_mode) {
                ._no_store_ => {
                    // Don't store request/response in cache
                    try headers_list.append(allocator, .{
                        .name = "Cache-Control",
                        .value = "no-store",
                    });
                },
                ._no_cache_ => {
                    // Revalidate with server before using cached response
                    try headers_list.append(allocator, .{
                        .name = "Cache-Control",
                        .value = "no-cache",
                    });
                },
                ._reload_ => {
                    // Ignore cache, fetch fresh from server
                    try headers_list.append(allocator, .{
                        .name = "Cache-Control",
                        .value = "no-cache",
                    });
                    try headers_list.append(allocator, .{
                        .name = "Pragma",
                        .value = "no-cache",
                    });
                },
                ._force_cache_ => {
                    // Use cache even if stale, only fetch if not cached
                    // No special headers needed - let cache decide
                },
                ._only_if_cached_ => {
                    // Only use cache, fail if not cached
                    // Note: This requires mode to be "same-origin"
                    try headers_list.append(allocator, .{
                        .name = "Cache-Control",
                        .value = "only-if-cached",
                    });
                },
                ._default_ => {
                    // Normal cache behavior - no special headers
                },
            }
        }

        // Credentials mode - controls cookie behavior
        // Spec: https://fetch.spec.whatwg.org/#dom-requestinit-credentials
        // TODO: Configure curl to send/receive cookies based on:
        // - omit: Don't send or receive cookies
        // - same-origin: Only for same-origin requests (default)
        // - include: Always send cookies, even cross-origin
        if (init_opts.credentials) |credentials| {
            _ = credentials; // Will be used when cookie jar is implemented
        }
    }

    // CORS handling: Add Origin header for cross-origin requests
    // Per WHATWG Fetch spec, cross-origin requests must include the Origin header
    // This is required for WPT tests that use alternate ports (e.g., localhost:8000 → localhost:8002)
    const document_origin = getDocumentOrigin(instance.ctx, allocator);
    const is_cross_origin = isCrossOrigin(document_origin, url_str);

    if (is_cross_origin) {
        if (document_origin) |origin| {
            std.debug.print("[FETCH] Cross-origin request detected. Adding Origin header: {s}\n", .{origin});
            try headers_list.append(allocator, .{
                .name = "Origin",
                .value = origin,
            });
        } else {
            // If we can't determine the document origin, use the request URL's origin as a fallback
            // This handles cases where the context doesn't have an api_base_url set
            if (extractOrigin(url_str)) |req_origin| {
                std.debug.print("[FETCH] Cross-origin request, using request origin as fallback: {s}\n", .{req_origin});
                try headers_list.append(allocator, .{
                    .name = "Origin",
                    .value = req_origin,
                });
            }
        }
    }

    // Try async path first (if network manager is available)
    if (instance.ctx.getNetworkManager()) |nm_ptr| {
        const async_curl: *AsyncCurlManager = @ptrCast(@alignCast(nm_ptr));
        std.debug.print("[FETCH] Using ASYNC path for URL: {s}\n", .{url_str});

        // Create completion context for the async callback
        const completion_ctx = allocator.create(FetchCompletionContext) catch {
            engine.rejectPromise(engine_ctx, promise_handle, error.OutOfMemory) catch {};
            return getPromiseAndCleanup(engine, promise_handle, allocator);
        };

        completion_ctx.* = .{
            .promise_handle = promise_handle,
            .allocator = allocator,
            .engine = engine,
            .engine_ctx = engine_ctx,
            .runtime_ctx = instance.ctx,
        };

        // Build NetworkRequest for async manager
        // Note: headers_list.items is a slice that survives until headers_list.deinit()
        // which happens after addRequest returns, so the headers are safely copied by curl
        const net_request = NetworkRequest{
            .url = url_str,
            .method = request_method,
            .headers = headers_list.items,
            .body = request_init.body,
            .follow_redirects = follow_redirects,
        };

        // Add the async request - returns immediately
        _ = async_curl.addRequest(&net_request, asyncFetchCompletionCallback, completion_ctx) catch |err| {
            completion_ctx.deinit();
            engine.rejectPromise(engine_ctx, promise_handle, err) catch {};
            return getPromiseAndCleanup(engine, promise_handle, allocator);
        };

        // Return Promise immediately - callback will resolve/reject when response arrives
        // Note: We DON'T call getPromiseAndCleanup here because the callback owns the promise handle
        const promise_obj = engine.getPromiseObject(promise_handle);
        return runtime.JSValue.fromHandle(promise_obj);
    }

    // FALLBACK: Synchronous path (no network manager)
    // This is used in tests or when Browser didn't set up async curl manager
    std.debug.print("[FETCH] Using SYNC fallback for URL: {s}\n", .{url_str});
    const result = global_fetch.globalFetch(allocator, .{ .url = url_str }, request_init);

    switch (result) {
        .response => |fetch_response| {
            // Get the InternalResponse from the fetch module's Response
            // We need to take ownership, so we'll extract and null out the internal
            const internal_response = fetch_response.internal;

            // Create a WebIDL Response instance wrapping the InternalResponse
            const response_instance = ResponseImpl.initWithInternalResponse(
                allocator,
                instance.ctx,
                internal_response,
            ) catch |err| {
                // On error, we need to clean up the internal response
                internal_response.deinit();
                // Also clean up the fetch Response wrapper (but not the internal we already handle)
                fetch_response.headers_obj.deinit();
                allocator.destroy(fetch_response);

                engine.rejectPromise(engine_ctx, promise_handle, err) catch {};
                return getPromiseAndCleanup(engine, promise_handle, allocator);
            };

            // Clean up the fetch Response wrapper without deiniting the internal
            // (ownership transferred to WebIDL Response)
            fetch_response.headers_obj.deinit();
            allocator.destroy(fetch_response);

            // Wrap the Response instance as a V8 object
            const wrapInstance = engine.wrapInstance orelse {
                engine.rejectPromise(engine_ctx, promise_handle, error.InvalidState) catch {};
                return getPromiseAndCleanup(engine, promise_handle, allocator);
            };

            const js_response = wrapInstance(engine_ctx, response_instance) catch {
                engine.rejectPromise(engine_ctx, promise_handle, error.InvalidState) catch {};
                return getPromiseAndCleanup(engine, promise_handle, allocator);
            };

            // Resolve the promise with the JS Response object
            engine.resolvePromise(engine_ctx, promise_handle, js_response) catch {};
        },
        .err => |fetch_err| {
            const fetch_error = switch (fetch_err) {
                global_fetch.FetchError.NetworkError => error.NetworkError,
                global_fetch.FetchError.AbortError => error.AbortError,
                global_fetch.FetchError.TypeError => error.TypeError,
                global_fetch.FetchError.OutOfMemory => error.OutOfMemory,
            };
            engine.rejectPromise(engine_ctx, promise_handle, fetch_error) catch {};
        },
    }

    return getPromiseAndCleanup(engine, promise_handle, allocator);
}

// Helper to get promise object and destroy handle to prevent memory leaks
fn getPromiseAndCleanup(engine: *const runtime.EngineInterface, promise_handle: *anyopaque, allocator: std.mem.Allocator) runtime.JSValue {
    const promise_obj = engine.getPromiseObject(promise_handle);
    if (engine.destroyPromiseHandle) |destroy| {
        destroy(promise_handle, allocator);
    }
    return runtime.JSValue.fromHandle(promise_obj);
}

/// Check if headers list contains a header with the given name (case-insensitive).
/// This is a helper for BodyInit Content-Type detection.
fn headersListContains(headers: []const NetworkRequest.Header, name: []const u8) bool {
    for (headers) |header| {
        if (std.ascii.eqlIgnoreCase(header.name, name)) {
            return true;
        }
    }
    return false;
}
