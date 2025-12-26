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
const AsyncResult = AsyncCurlManager.AsyncResult;

// Body extraction support
const BlobImpl = @import("Blob.zig");
const URLSearchParamsImpl = @import("URLSearchParams.zig");

// Form serialization for URLSearchParams body
const form_serializer = @import("form_serializer");

pub const State = WindowOrWorkerGlobalScope.State;

pub const ImplError = error{
    NotImplemented,
};

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
    const allocator = instance.allocator;

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
            // Get URL from Request instance
            const req_url = interfaces.Request.get_url(req_instance) catch {
                std.debug.print("[Fetch] Failed to get URL from Request\n", .{});
                engine.rejectPromise(engine_ctx, promise_handle, error.TypeError) catch {};
                return getPromiseAndCleanup(engine, promise_handle, allocator);
            };
            std.debug.print("[Fetch] Input URL from Request: {s}\n", .{req_url});
            break :blk req_url;
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
        }

        // Headers - convert from HeadersInit to internal format
        // HeadersInit can be sequence<sequence<ByteString>> or record<ByteString, ByteString>
        if (init_opts.headers) |headers_init| {
            switch (headers_init) {
                .sequence_byte_string_sequence => |seq| {
                    // Each inner sequence should have 2 elements: [name, value]
                    // TODO: Convert to internal headers format
                    _ = seq;
                },
                .byte_string_byte_string_record => |record| {
                    // Key-value pairs
                    // TODO: Convert to internal headers format
                    _ = record;
                },
            }
        }

        // Body - convert from BodyInit to internal format
        // Spec: https://fetch.spec.whatwg.org/#bodyinit-safely-extract
        if (init_opts.body) |body_init| {
            switch (body_init) {
                .xmlhttp_request_body_init => |xhr_body| {
                    switch (xhr_body) {
                        .usvstring => |s| {
                            request_init.body = s;
                            // Content-Type should be "text/plain;charset=UTF-8" if not set
                        },
                        .blob => |blob_instance| {
                            // Extract bytes from Blob's internal state
                            if (BlobImpl.getInternal(blob_instance)) |internal| {
                                request_init.body = internal.blob_data.bytes;
                                // Content-Type should be blob's type if not empty and headers don't have Content-Type
                            }
                        },
                        .buffer_source => |buffer_source| {
                            // Extract bytes from BufferSource (ArrayBuffer or ArrayBufferView)
                            const bytes = buffer_source.asBytes() catch null;
                            if (bytes) |b| {
                                request_init.body = b;
                                // No default Content-Type for BufferSource
                            }
                        },
                        .urlsearch_params => |usp_instance| {
                            // Serialize URLSearchParams to application/x-www-form-urlencoded
                            const serialized = URLSearchParamsImpl.serialize(usp_instance) catch null;
                            if (serialized) |s| {
                                request_init.body = s;
                                // Content-Type should be "application/x-www-form-urlencoded;charset=UTF-8"
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

        // Mode, credentials, cache, redirect, referrer, referrerPolicy are passed
        // but the internal fetch API currently uses defaults
        // TODO: Pass these through when internal fetch supports them
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
        var net_request = NetworkRequest{
            .url = url_str,
            .method = .GET,
        };

        // Set method from request_init
        if (request_init.method) |method_str| {
            net_request.method = network.HttpMethod.fromString(method_str) catch .GET;
        }

        // Set body from request_init
        if (request_init.body) |body| {
            net_request.body = body;
        }

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
