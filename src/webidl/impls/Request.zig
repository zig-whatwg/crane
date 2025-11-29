//! Implementation for Request interface
//!
//! Wraps Fetch internal InternalRequest to provide WebIDL interface.
//! Spec: https://fetch.spec.whatwg.org/#request-class
//!
//! NOTE: Implementing Option B (full constructor + body methods)

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");

// Import Fetch internal structures
const fetch = @import("fetch");
const InternalRequest = fetch.internal.InternalRequest;

// Import File API for Blob support
const file = @import("file");
const BlobData = file.BlobData;

// Import Blob WebIDL wrapper
const BlobImpl = @import("Blob.zig");
const webidl = @import("webidl");

// RequestInit is now properly defined in dictionaries with all Fetch spec fields

const Request = interfaces.Request;

pub const State = Request.State;

pub const ImplError = error{
    OutOfMemory,
    TypeError,
    InvalidState,
};

/// Convert WebIDL RequestMode enum to internal RequestMode enum
fn toInternalMode(mode: enums.RequestMode) fetch.internal.RequestMode {
    return switch (mode) {
        ._navigate_ => .navigate,
        ._same_origin_ => .same_origin,
        ._no_cors_ => .no_cors,
        ._cors_ => .cors,
    };
}

/// Convert internal RequestMode enum to WebIDL RequestMode enum
fn toWebIDLMode(mode: fetch.internal.RequestMode) enums.RequestMode {
    return switch (mode) {
        .navigate => ._navigate_,
        .same_origin => ._same_origin_,
        .no_cors => ._no_cors_,
        .cors => ._cors_,
        .websocket => ._navigate_, // Map websocket to navigate
    };
}

/// Convert WebIDL RequestCredentials to internal CredentialsMode
fn toInternalCredentials(creds: enums.RequestCredentials) fetch.internal.CredentialsMode {
    return switch (creds) {
        ._omit_ => .omit,
        ._same_origin_ => .same_origin,
        ._include_ => .include,
    };
}

/// Convert WebIDL RequestCache to internal CacheMode
fn toInternalCache(cache: enums.RequestCache) fetch.internal.CacheMode {
    return switch (cache) {
        ._default_ => .default,
        ._no_store_ => .no_store,
        ._reload_ => .reload,
        ._no_cache_ => .no_cache,
        ._force_cache_ => .force_cache,
        ._only_if_cached_ => .only_if_cached,
    };
}

/// Convert WebIDL RequestRedirect to internal RedirectMode
fn toInternalRedirect(redirect: enums.RequestRedirect) fetch.internal.RedirectMode {
    return switch (redirect) {
        ._follow_ => .follow,
        ._error_ => .@"error",
        ._manual_ => .manual,
    };
}

/// Internal state wraps Fetch InternalRequest
pub const InternalState = struct {
    allocator: std.mem.Allocator,
    request: *InternalRequest,
    headers_cache: ?*runtime.Instance = null, // Cached Headers instance
};

/// Initialize instance
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    const instance = try runtime.Instance.init(allocator, StateType, vtable, ctx);
    errdefer runtime.Instance.deinit(instance);

    // Create internal state
    const internal = try allocator.create(InternalState);
    errdefer allocator.destroy(internal);

    // Create internal request with default URL
    const request = try InternalRequest.init(allocator, "");
    errdefer request.deinit();

    internal.* = .{
        .allocator = allocator,
        .request = request,
        .headers_cache = null,
    };

    // Store in instance
    const state = instance.getState(StateType);
    state.own._internal = internal;

    return instance;
}

/// Deinitialize
pub fn deinit(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        const allocator = internal.allocator;
        // Clean up cached headers if exists
        if (internal.headers_cache) |headers| {
            const Headers = @import("Headers.zig");
            Headers.deinit(headers);
        }
        internal.request.deinit();
        allocator.destroy(internal);
    }
    runtime.Instance.deinit(instance);
}

/// Constructor - implements full Request(input, init) constructor algorithm
/// Spec: https://fetch.spec.whatwg.org/#dom-request
pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, input: typedefs.RequestInfo, init_data: webidl.Opt(dictionaries.RequestInit)) !*runtime.Instance {
    // Get the RequestInit options if passed
    const init_opts: dictionaries.RequestInit = if (init_data.wasPassed())
        init_data.getValue()
    else
        .{};

    // Step 1: Let request be null (will be InternalRequest)
    var base_request: *InternalRequest = undefined;

    // Step 2: Let fallbackMode be null
    var fallback_mode: ?enums.RequestMode = null;

    // Step 3: Let baseURL be this's relevant settings object's API base URL
    // TODO: Get from context when needed

    // Step 4: Let signal be null
    var signal: ?*runtime.Instance = null;

    // Step 5: If input is a string
    switch (input) {
        .variant_1 => |url_string| {
            // Step 5.1: Parse URL
            const api_parser = @import("api_parser");
            var parsed_url = api_parser.parseURL(allocator, url_string, null) catch {
                return error.TypeError; // Step 5.2: If parsedURL is failure, throw TypeError
            };
            defer parsed_url.deinit();

            // Step 5.3: If parsedURL includes credentials, throw TypeError
            if (parsed_url.username().len > 0 or parsed_url.password().len > 0) {
                return error.TypeError;
            }

            // Step 5.4: Create new request with URL
            const url_serializer = @import("url_serializer");
            const serialized_url = try url_serializer.serialize(allocator, &parsed_url, false);
            defer allocator.free(serialized_url);

            base_request = try InternalRequest.init(allocator, serialized_url);

            // Step 5.5: Set fallbackMode to "cors"
            fallback_mode = enums.RequestMode._cors_;
        },
        .variant_0 => |input_request_opaque| {
            // Step 6: Otherwise (input is a Request object)
            // Step 6.1: Assert input is a Request object
            const input_request = @as(*runtime.Instance, @ptrFromInt(@intFromPtr(input_request_opaque)));
            const input_state = input_request.getState(State);
            const input_internal = input_state.own._internal.?;

            // Step 6.2: Set request to input's request
            // Clone the request
            base_request = try input_internal.request.clone();

            // Step 6.3: Set signal to input's signal
            // TODO: Get signal from input_state
            signal = null;
        },
    }
    errdefer base_request.deinit();

    // Step 12: Set request to a new request (copy of base with modifications)
    // For now, we'll modify base_request in place and create the final instance

    // Step 13: If init is not empty
    const init_is_empty = (init_opts.method == null and
        init_opts.headers == null and
        init_opts.body == null and
        init_opts.referrer == null and
        init_opts.referrerPolicy == null and
        init_opts.mode == null and
        init_opts.credentials == null and
        init_opts.cache == null and
        init_opts.redirect == null and
        init_opts.integrity == null and
        init_opts.keepalive == null and
        init_opts.signal == null and
        init_opts.duplex == null and
        init_opts.priority == null);

    if (!init_is_empty) {
        // Step 13.1: If request's mode is "navigate", set it to "same-origin"
        if (base_request.mode == .navigate) {
            base_request.mode = .same_origin;
        }

        // Steps 13.2-8: Reset various fields
        // (Most of these are already defaults in InternalRequest.init)
    }

    // Step 25: If init["method"] exists
    if (init_opts.method) |method| {
        // Step 25.1: Let method = init["method"]
        // Step 25.2: If method is not a method or is forbidden, throw TypeError
        // TODO: Validate method

        // Step 25.3: Normalize method (uppercase standard methods)
        // Step 25.4: Set request's method to method
        base_request.method = normalizeMethod(method);
    }

    // Step 16-18: Handle mode
    const mode = init_opts.mode orelse fallback_mode;
    if (mode) |m| {
        // Step 17: If mode is "navigate", throw TypeError
        if (m == enums.RequestMode._navigate_) {
            return error.TypeError;
        }
        // Step 18: Set request's mode (convert to internal enum)
        base_request.mode = toInternalMode(m);
    }

    // Step 19: If init["credentials"] exists
    if (init_opts.credentials) |creds| {
        base_request.credentials_mode = toInternalCredentials(creds);
    }

    // Step 20: If init["cache"] exists
    if (init_opts.cache) |cache_mode| {
        base_request.cache_mode = toInternalCache(cache_mode);
    }

    // Step 21: Validate cache mode
    if (base_request.cache_mode == .only_if_cached and base_request.mode != .same_origin) {
        return error.TypeError;
    }

    // Step 22: If init["redirect"] exists
    if (init_opts.redirect) |redirect_mode| {
        base_request.redirect_mode = toInternalRedirect(redirect_mode);
    }

    // Step 23: If init["integrity"] exists
    if (init_opts.integrity) |integrity| {
        // TODO: Handle DOMString union properly
        _ = integrity;
    }

    // Step 24: If init["keepalive"] exists
    if (init_opts.keepalive) |keepalive| {
        base_request.keepalive = keepalive;
    }

    // Step 31-34: Handle headers from init BEFORE creating instance
    // This ensures all headers are added while base_request is still the owner
    if (init_opts.headers) |headers_init| {
        // Fill the request's headers with headers_init
        switch (headers_init) {
            .pairs => |pairs| {
                // Array of [name, value] pairs
                for (pairs) |pair| {
                    try base_request.header_list.append(pair[0], pair[1]);
                }
            },
            .record => |entries| {
                // Object with header entries
                for (entries) |entry| {
                    try base_request.header_list.append(entry.name, entry.value);
                }
            },
            .headers_ptr => |ptr| {
                // Existing Headers object - copy its entries
                const Headers = @import("Headers.zig");
                const other_instance: *runtime.Instance = @ptrCast(@alignCast(@constCast(ptr)));
                if (Headers.getEntriesInternal(other_instance)) |entries| {
                    for (entries) |entry| {
                        try base_request.header_list.append(entry.name, entry.value);
                    }
                }
            },
            .v8_value => {
                // V8 value fallback - should be handled by V8 layer before reaching here
                // If we get here, we can't parse it
            },
        }
    }

    // Step 35: Validate GET/HEAD don't have body BEFORE creating instance
    const has_init_body = init_opts.body != null;
    const method_is_get_or_head = std.mem.eql(u8, base_request.method, "GET") or
        std.mem.eql(u8, base_request.method, "HEAD");

    if (has_init_body and method_is_get_or_head) {
        return error.TypeError;
    }

    // Now create the instance with the configured request
    const instance = try init(allocator, State, &Request.vtable, ctx);
    // Note: After this point, instance.deinit will clean up on error

    // Replace the default request with our configured one
    const state = instance.getState(State);
    const internal = state.own._internal.?;
    internal.request.deinit(); // Free the default empty request
    internal.request = base_request; // Transfer ownership

    // TODO: Steps 36-42: Handle body parsing
    // For now, body is stubbed

    return instance;
}

// === Property Getters ===

/// Get method
pub fn get_method(instance: *runtime.Instance) ImplError!runtime.ByteString {
    const state = instance.getState(State);
    const internal = state.own._internal.?;
    return internal.request.method;
}

/// Get URL
pub fn get_url(instance: *runtime.Instance) ImplError!runtime.USVString {
    const state = instance.getState(State);
    const internal = state.own._internal.?;
    // Use accessor method - returns first URL in url_list
    return internal.request.getUrl();
}

/// Get headers - creates and caches Headers instance on first access
pub fn get_headers(instance: *runtime.Instance) ImplError!*runtime.Instance {
    const state = instance.getState(State);
    const internal = state.own._internal.?;

    // Return cached instance if exists
    if (internal.headers_cache) |headers| {
        return headers;
    }

    // Create Headers instance wrapping our header_list with "request" guard
    const Headers = @import("Headers.zig");
    const headers = try Headers.initWithHeaderList(
        internal.allocator,
        instance.ctx,
        &internal.request.header_list,
        .request,
    );

    // Cache it
    internal.headers_cache = headers;

    return headers;
}

/// Get destination
pub fn get_destination(instance: *runtime.Instance) ImplError!enums.RequestDestination {
    const state = instance.getState(State);
    const internal = state.own._internal.?;

    // Map internal destination to WebIDL enum
    return switch (internal.request.destination) {
        .empty => .__,
        .audio => ._audio_,
        .audioworklet => ._audioworklet_,
        .document => ._document_,
        .embed => ._embed_,
        .font => ._font_,
        .frame => ._frame_,
        .iframe => ._iframe_,
        .image => ._image_,
        .json => ._json_,
        .manifest => ._manifest_,
        .object => ._object_,
        .paintworklet => ._paintworklet_,
        .report => ._report_,
        .script => ._script_,
        .serviceworker => ._script_, // serviceworker not in WebIDL enum
        .sharedworker => ._sharedworker_,
        .style => ._style_,
        .track => ._track_,
        .video => ._video_,
        .webidentity => .__, // webidentity not in WebIDL enum
        .worker => ._worker_,
        .xslt => ._xslt_,
    };
}

/// Get referrer
pub fn get_referrer(instance: *runtime.Instance) ImplError!runtime.USVString {
    const state = instance.getState(State);
    const internal = state.own._internal.?;

    return switch (internal.request.referrer) {
        .no_referrer => "",
        .client => "about:client",
        .url => |url| url,
    };
}

/// Get referrerPolicy
pub fn get_referrerPolicy(instance: *runtime.Instance) ImplError!enums.ReferrerPolicy {
    const state = instance.getState(State);
    const internal = state.own._internal.?;

    return switch (internal.request.referrer_policy) {
        .empty => .__,
        .no_referrer => ._no_referrer_,
        .no_referrer_when_downgrade => ._no_referrer_when_downgrade_,
        .same_origin => ._same_origin_,
        .origin => ._origin_,
        .strict_origin => ._strict_origin_,
        .origin_when_cross_origin => ._origin_when_cross_origin_,
        .strict_origin_when_cross_origin => ._strict_origin_when_cross_origin_,
        .unsafe_url => ._unsafe_url_,
    };
}

/// Get mode
pub fn get_mode(instance: *runtime.Instance) ImplError!enums.RequestMode {
    const state = instance.getState(State);
    const internal = state.own._internal.?;

    return switch (internal.request.mode) {
        .same_origin => ._same_origin_,
        .cors => ._cors_,
        .no_cors => ._no_cors_,
        .navigate => ._navigate_,
        .websocket => ._navigate_, // websocket not in WebIDL enum, use navigate
    };
}

/// Get credentials
pub fn get_credentials(instance: *runtime.Instance) ImplError!enums.RequestCredentials {
    const state = instance.getState(State);
    const internal = state.own._internal.?;

    return switch (internal.request.credentials_mode) {
        .omit => ._omit_,
        .same_origin => ._same_origin_,
        .include => ._include_,
    };
}

/// Get cache
pub fn get_cache(instance: *runtime.Instance) ImplError!enums.RequestCache {
    const state = instance.getState(State);
    const internal = state.own._internal.?;

    return switch (internal.request.cache_mode) {
        .default => ._default_,
        .no_store => ._no_store_,
        .reload => ._reload_,
        .no_cache => ._no_cache_,
        .force_cache => ._force_cache_,
        .only_if_cached => ._only_if_cached_,
    };
}

/// Get redirect
pub fn get_redirect(instance: *runtime.Instance) ImplError!enums.RequestRedirect {
    const state = instance.getState(State);
    const internal = state.own._internal.?;

    return switch (internal.request.redirect_mode) {
        .follow => ._follow_,
        .@"error" => ._error_,
        .manual => ._manual_,
    };
}

/// Get integrity
pub fn get_integrity(instance: *runtime.Instance) ImplError!runtime.DOMString {
    const state = instance.getState(State);
    const internal = state.own._internal.?;

    // integrity_metadata is []const u8, convert to DOMString
    if (internal.request.integrity_metadata.len == 0) {
        return runtime.DOMString.initEmpty();
    }
    return runtime.DOMString.initInterned(internal.request.integrity_metadata);
}

/// Get keepalive
pub fn get_keepalive(instance: *runtime.Instance) ImplError!bool {
    const state = instance.getState(State);
    const internal = state.own._internal.?;

    return internal.request.keepalive;
}

/// Get isReloadNavigation
pub fn get_isReloadNavigation(instance: *runtime.Instance) ImplError!bool {
    const state = instance.getState(State);
    const internal = state.own._internal.?;

    return internal.request.reload_navigation;
}

/// Get isHistoryNavigation
pub fn get_isHistoryNavigation(instance: *runtime.Instance) ImplError!bool {
    const state = instance.getState(State);
    const internal = state.own._internal.?;

    return internal.request.history_navigation;
}

/// Get signal - Return from state field
pub fn get_signal(instance: *runtime.Instance) ImplError!*runtime.Instance {
    const state = instance.getState(State);
    return state.own.signal;
}

/// Get duplex
pub fn get_duplex(instance: *runtime.Instance) ImplError!enums.RequestDuplex {
    _ = instance;
    // TODO (Option B): Track duplex mode in InternalRequest
    return ._half_;
}

/// Get targetAddressSpace
pub fn get_targetAddressSpace(instance: *runtime.Instance) ImplError!enums.IPAddressSpace {
    _ = instance;
    // TODO (Option B): Implement target address space from InternalRequest
    return ._public_; // Default to public
}

// === Body Mixin Properties ===

/// Get body
pub fn get_body(instance: *runtime.Instance) ImplError!?*runtime.Instance {
    const state = instance.getState(State);
    return state.own.body;
}

/// Get bodyUsed
pub fn get_bodyUsed(instance: *runtime.Instance) ImplError!bool {
    const state = instance.getState(State);
    return state.own.bodyUsed;
}

// === Methods - STUBS (Option A) ===

/// clone() - Clones the Request
/// Spec: https://fetch.spec.whatwg.org/#dom-request-clone
pub fn call_clone(instance: *runtime.Instance) ImplError!*runtime.Instance {
    const state = instance.getState(State);
    const internal = state.own._internal.?;

    // Step 1: If this is unusable, throw TypeError
    if (internal.request.body) |body| {
        switch (body) {
            .body => |body_obj| {
                if (body_obj.isDisturbed()) {
                    return error.TypeError;
                }
            },
            .bytes => {},
        }
    }

    // Step 2: Clone the internal request
    const cloned_request = try internal.request.clone();
    errdefer cloned_request.deinit();

    // Step 3-6: Create new Request instance with cloned request
    const cloned_instance = try init(internal.allocator, State, &Request.vtable, instance.ctx);
    errdefer deinit(cloned_instance);

    const cloned_state = cloned_instance.getState(State);
    const cloned_internal = cloned_state.own._internal.?;

    // Replace default request with cloned one
    cloned_internal.request.deinit();
    cloned_internal.request = cloned_request;

    // TODO: Clone AbortSignal and create dependent signal (step 4-5)
    // For now, we just clone the request structure

    return cloned_instance;
}

/// arrayBuffer() - Returns promise fulfilled with body as ArrayBuffer
/// Spec: https://fetch.spec.whatwg.org/#dom-body-arraybuffer
pub fn call_arrayBuffer(instance: *runtime.Instance) ImplError!*const anyopaque {
    const state = instance.getState(State);
    const internal = state.own._internal.?;

    const event_loop = instance.ctx.getEventLoop() catch {
        return error.InvalidState;
    };

    const AsyncPromise = @import("streams_async_promise").AsyncPromise;
    // ArrayBuffer from arraybuffer_view (simple implementation for Streams BYOB)
    const ArrayBufferView = @import("runtime").arraybuffer_view;
    var promise = try AsyncPromise(ArrayBufferView.ArrayBuffer).init(
        internal.allocator,
        event_loop,
    );

    if (internal.request.body) |body| {
        switch (body) {
            .bytes => |bytes| {
                // Create ArrayBuffer from bytes
                const buffer = try ArrayBufferView.ArrayBuffer.init(internal.allocator, bytes.len);
                @memcpy(buffer.data, bytes);
                promise.fulfill(buffer);
            },
            .body => |body_obj| {
                if (body_obj.isDisturbed()) {
                    const exception = @import("webidl").errors.Exception{
                        .simple = .{ .type = .TypeError, .message = "Body is unusable (already read)" },
                    };
                    promise.reject(exception);
                } else {
                    const bytes = body_obj.readAllBytes() catch {
                        const exception = @import("webidl").errors.Exception{
                            .simple = .{ .type = .TypeError, .message = "Failed to read body" },
                        };
                        promise.reject(exception);
                        return @ptrCast(promise);
                    };

                    const buffer = try ArrayBufferView.ArrayBuffer.init(internal.allocator, bytes.len);
                    @memcpy(buffer.data, bytes);
                    promise.fulfill(buffer);
                }
            },
        }
    } else {
        // Null body - create empty ArrayBuffer
        const buffer = try ArrayBufferView.ArrayBuffer.init(internal.allocator, 0);
        promise.fulfill(buffer);
    }

    return @ptrCast(promise);
}

/// blob() - Returns promise fulfilled with body as Blob
/// Spec: https://fetch.spec.whatwg.org/#dom-body-blob
pub fn call_blob(instance: *runtime.Instance) ImplError!*const anyopaque {
    const state = instance.getState(State);
    const internal = state.own._internal.?;

    const event_loop = instance.ctx.getEventLoop() catch {
        return error.InvalidState;
    };

    const AsyncPromise = @import("streams_async_promise").AsyncPromise;
    var promise = try AsyncPromise(*runtime.Instance).init(
        internal.allocator,
        event_loop,
    );

    // Get MIME type from Content-Type header
    const mime_type = blk: {
        const ct = internal.request.header_list.get(internal.allocator, "content-type") catch null;
        break :blk ct orelse "";
    };

    if (internal.request.body) |body| {
        switch (body) {
            .bytes => |bytes| {
                // Create BlobData from bytes
                const blob_data = try BlobData.init(internal.allocator, bytes, mime_type);
                errdefer blob_data.deinit();

                // Wrap in Blob WebIDL instance
                const blob_instance = BlobImpl.createFromBlobData(
                    internal.allocator,
                    instance.ctx,
                    blob_data,
                ) catch {
                    blob_data.deinit();
                    const exception = @import("webidl").errors.Exception{
                        .simple = .{ .type = .TypeError, .message = "Failed to create Blob wrapper" },
                    };
                    promise.reject(exception);
                    return @ptrCast(promise);
                };

                // Fulfill promise with Blob instance
                promise.fulfill(blob_instance);
            },
            .body => |body_obj| {
                if (body_obj.isDisturbed()) {
                    const exception = @import("webidl").errors.Exception{
                        .simple = .{ .type = .TypeError, .message = "Body is unusable (already read)" },
                    };
                    promise.reject(exception);
                } else {
                    const bytes = body_obj.readAllBytes() catch {
                        const exception = @import("webidl").errors.Exception{
                            .simple = .{ .type = .TypeError, .message = "Failed to read body" },
                        };
                        promise.reject(exception);
                        return @ptrCast(promise);
                    };

                    const blob_data = try BlobData.init(internal.allocator, bytes, mime_type);
                    errdefer blob_data.deinit();

                    // Wrap in Blob WebIDL instance
                    const blob_instance = BlobImpl.createFromBlobData(
                        internal.allocator,
                        instance.ctx,
                        blob_data,
                    ) catch {
                        blob_data.deinit();
                        const exception = @import("webidl").errors.Exception{
                            .simple = .{ .type = .TypeError, .message = "Failed to create Blob wrapper" },
                        };
                        promise.reject(exception);
                        return @ptrCast(promise);
                    };

                    // Fulfill promise with Blob instance
                    promise.fulfill(blob_instance);
                }
            },
        }
    } else {
        // Null body - create empty Blob
        const blob_data = try BlobData.init(internal.allocator, &[_]u8{}, mime_type);
        errdefer blob_data.deinit();

        const blob_instance = BlobImpl.createFromBlobData(
            internal.allocator,
            instance.ctx,
            blob_data,
        ) catch {
            blob_data.deinit();
            const exception = @import("webidl").errors.Exception{
                .simple = .{ .type = .TypeError, .message = "Failed to create Blob wrapper" },
            };
            promise.reject(exception);
            return @ptrCast(promise);
        };

        // Fulfill promise with Blob instance
        promise.fulfill(blob_instance);
    }

    return @ptrCast(promise);
}

/// bytes() - Returns promise fulfilled with body as Uint8Array
/// Spec: https://fetch.spec.whatwg.org/#dom-body-bytes
pub fn call_bytes(instance: *runtime.Instance) ImplError!*const anyopaque {
    const state = instance.getState(State);
    const internal = state.own._internal.?;

    // Get event loop from context
    const event_loop = instance.ctx.getEventLoop() catch {
        return error.InvalidState;
    };

    // Create AsyncPromise for byte array result
    const AsyncPromise = @import("streams_async_promise").AsyncPromise;
    var promise = try AsyncPromise([]const u8).init(
        internal.allocator,
        event_loop,
    );

    // Check if unusable (step 1 of consume body algorithm)
    if (internal.request.body) |body| {
        switch (body) {
            .bytes => |bytes| {
                // For byte sequence bodies, return as-is
                const bytes_copy = try internal.allocator.dupe(u8, bytes);
                promise.fulfill(bytes_copy);
            },
            .body => |body_obj| {
                // Check if body is disturbed or locked (unusable)
                if (body_obj.isDisturbed()) {
                    const exception = @import("webidl").errors.Exception{
                        .simple = .{ .type = .TypeError, .message = "Body is unusable (already read)" },
                    };
                    promise.reject(exception);
                } else {
                    // Read all bytes from body
                    const bytes = body_obj.readAllBytes() catch {
                        const exception = @import("webidl").errors.Exception{
                            .simple = .{ .type = .TypeError, .message = "Failed to read body" },
                        };
                        promise.reject(exception);
                        return @ptrCast(promise);
                    };

                    // Return bytes (allocate copy)
                    const bytes_copy = try internal.allocator.dupe(u8, bytes);
                    promise.fulfill(bytes_copy);
                }
            },
        }
    } else {
        // Null body - fulfill with empty byte array
        const empty = try internal.allocator.alloc(u8, 0);
        promise.fulfill(empty);
    }

    return @ptrCast(promise);
}

/// formData() - Returns promise fulfilled with body as FormData
/// Spec: https://fetch.spec.whatwg.org/#dom-body-formdata
pub fn call_formData(instance: *runtime.Instance) ImplError!*const anyopaque {
    const state = instance.getState(State);
    const internal = state.own._internal.?;

    const event_loop = instance.ctx.getEventLoop() catch {
        return error.InvalidState;
    };

    const AsyncPromise = @import("streams_async_promise").AsyncPromise;
    const FormDataImpl = @import("FormData.zig");
    const xhr = @import("xhr");
    const multipart_parser = xhr.multipart_parser;
    const url_parser = @import("form_parser"); // form_parser module from build.zig

    var promise = try AsyncPromise(*runtime.Instance).init(
        internal.allocator,
        event_loop,
    );

    // Get Content-Type header
    const content_type = internal.request.header_list.get(internal.allocator, "content-type") catch null;

    if (internal.request.body) |body| {
        // Read body bytes
        const bytes = switch (body) {
            .bytes => |b| b,
            .body => |body_obj| blk: {
                if (body_obj.isDisturbed()) {
                    const exception = @import("webidl").errors.Exception{
                        .simple = .{ .type = .TypeError, .message = "Body is unusable (already read)" },
                    };
                    promise.reject(exception);
                    return @ptrCast(promise);
                }
                break :blk body_obj.readAllBytes() catch {
                    const exception = @import("webidl").errors.Exception{
                        .simple = .{ .type = .TypeError, .message = "Failed to read body" },
                    };
                    promise.reject(exception);
                    return @ptrCast(promise);
                };
            },
        };

        // Route to appropriate parser based on Content-Type
        const form_data = if (content_type) |ct| parse_blk: {
            if (std.mem.indexOf(u8, ct, "multipart/form-data") != null) {
                // Extract boundary and parse multipart
                const boundary = multipart_parser.extractBoundary(internal.allocator, ct) catch {
                    const exception = @import("webidl").errors.Exception{
                        .simple = .{ .type = .TypeError, .message = "Invalid multipart Content-Type (missing boundary)" },
                    };
                    promise.reject(exception);
                    return @ptrCast(promise);
                };
                defer internal.allocator.free(boundary);

                const entries = multipart_parser.parseMultipartFormData(internal.allocator, bytes, boundary) catch {
                    const exception = @import("webidl").errors.Exception{
                        .simple = .{ .type = .TypeError, .message = "Failed to parse multipart/form-data body" },
                    };
                    promise.reject(exception);
                    return @ptrCast(promise);
                };
                defer {
                    for (entries) |*entry| entry.deinit(internal.allocator);
                    internal.allocator.free(entries);
                }

                // Build FormData from entries
                const fd = xhr.form_data.FormData.init(internal.allocator) catch {
                    const exception = @import("webidl").errors.Exception{
                        .simple = .{ .type = .TypeError, .message = "Failed to create FormData" },
                    };
                    promise.reject(exception);
                    return @ptrCast(promise);
                };
                errdefer fd.deinit();

                for (entries) |entry| {
                    switch (entry.value) {
                        .string => |s| try fd.appendString(entry.name, s),
                        .file => |f| try fd.appendFile(entry.name, f, entry.filename),
                    }
                }

                break :parse_blk fd;
            } else if (std.mem.indexOf(u8, ct, "application/x-www-form-urlencoded") != null) {
                // Parse URL-encoded
                const tuples = url_parser.parse(internal.allocator, bytes) catch {
                    const exception = @import("webidl").errors.Exception{
                        .simple = .{ .type = .TypeError, .message = "Failed to parse URL-encoded body" },
                    };
                    promise.reject(exception);
                    return @ptrCast(promise);
                };
                defer {
                    for (tuples) |tuple| tuple.deinit(internal.allocator);
                    internal.allocator.free(tuples);
                }

                // Build FormData from tuples
                const fd = xhr.form_data.FormData.init(internal.allocator) catch {
                    const exception = @import("webidl").errors.Exception{
                        .simple = .{ .type = .TypeError, .message = "Failed to create FormData" },
                    };
                    promise.reject(exception);
                    return @ptrCast(promise);
                };
                errdefer fd.deinit();

                for (tuples) |tuple| {
                    try fd.appendString(tuple.name, tuple.value);
                }

                break :parse_blk fd;
            } else {
                const exception = @import("webidl").errors.Exception{
                    .simple = .{ .type = .TypeError, .message = "Invalid Content-Type for FormData (expected multipart/form-data or application/x-www-form-urlencoded)" },
                };
                promise.reject(exception);
                return @ptrCast(promise);
            }
        } else url_blk: {
            // No Content-Type header - default to URL-encoded
            const tuples = url_parser.parse(internal.allocator, bytes) catch {
                const exception = @import("webidl").errors.Exception{
                    .simple = .{ .type = .TypeError, .message = "Failed to parse body as URL-encoded" },
                };
                promise.reject(exception);
                return @ptrCast(promise);
            };
            defer {
                for (tuples) |tuple| tuple.deinit(internal.allocator);
                internal.allocator.free(tuples);
            }

            const fd = xhr.form_data.FormData.init(internal.allocator) catch {
                const exception = @import("webidl").errors.Exception{
                    .simple = .{ .type = .TypeError, .message = "Failed to create FormData" },
                };
                promise.reject(exception);
                return @ptrCast(promise);
            };
            errdefer fd.deinit();

            for (tuples) |tuple| {
                try fd.appendString(tuple.name, tuple.value);
            }

            break :url_blk fd;
        };

        // Wrap in WebIDL instance
        const formdata_instance = FormDataImpl.createFromInternal(
            internal.allocator,
            instance.ctx,
            form_data,
        ) catch {
            form_data.deinit();
            const exception = @import("webidl").errors.Exception{
                .simple = .{ .type = .TypeError, .message = "Failed to create FormData wrapper" },
            };
            promise.reject(exception);
            return @ptrCast(promise);
        };

        // Fulfill promise
        promise.fulfill(formdata_instance);
    } else {
        // Empty body - create empty FormData
        const form_data = xhr.form_data.FormData.init(internal.allocator) catch {
            const exception = @import("webidl").errors.Exception{
                .simple = .{ .type = .TypeError, .message = "Failed to create FormData" },
            };
            promise.reject(exception);
            return @ptrCast(promise);
        };

        const formdata_instance = FormDataImpl.createFromInternal(
            internal.allocator,
            instance.ctx,
            form_data,
        ) catch {
            form_data.deinit();
            const exception = @import("webidl").errors.Exception{
                .simple = .{ .type = .TypeError, .message = "Failed to create FormData wrapper" },
            };
            promise.reject(exception);
            return @ptrCast(promise);
        };

        promise.fulfill(formdata_instance);
    }

    return @ptrCast(promise);
}

/// json() - Returns promise fulfilled with body parsed as JSON
/// Spec: https://fetch.spec.whatwg.org/#dom-body-json
pub fn call_json(instance: *runtime.Instance) ImplError!*const anyopaque {
    const state = instance.getState(State);
    const internal = state.own._internal.?;

    const event_loop = instance.ctx.getEventLoop() catch {
        return error.InvalidState;
    };

    // JSON can be any type - use std.json.Value
    const AsyncPromise = @import("streams_async_promise").AsyncPromise;
    var promise = try AsyncPromise(std.json.Value).init(
        internal.allocator,
        event_loop,
    );

    if (internal.request.body) |body| {
        switch (body) {
            .bytes => |bytes| {
                // Parse JSON from bytes
                const parsed = std.json.parseFromSlice(
                    std.json.Value,
                    internal.allocator,
                    bytes,
                    .{},
                ) catch {
                    const exception = @import("webidl").errors.Exception{
                        .simple = .{ .type = .SyntaxError, .message = "Invalid JSON" },
                    };
                    promise.reject(exception);
                    return @ptrCast(promise);
                };
                promise.fulfill(parsed.value);
            },
            .body => |body_obj| {
                if (body_obj.isDisturbed()) {
                    const exception = @import("webidl").errors.Exception{
                        .simple = .{ .type = .TypeError, .message = "Body is unusable (already read)" },
                    };
                    promise.reject(exception);
                } else {
                    const bytes = body_obj.readAllBytes() catch {
                        const exception = @import("webidl").errors.Exception{
                            .simple = .{ .type = .TypeError, .message = "Failed to read body" },
                        };
                        promise.reject(exception);
                        return @ptrCast(promise);
                    };

                    // Parse JSON
                    const parsed = std.json.parseFromSlice(
                        std.json.Value,
                        internal.allocator,
                        bytes,
                        .{},
                    ) catch {
                        const exception = @import("webidl").errors.Exception{
                            .simple = .{ .type = .SyntaxError, .message = "Invalid JSON" },
                        };
                        promise.reject(exception);
                        return @ptrCast(promise);
                    };
                    promise.fulfill(parsed.value);
                }
            },
        }
    } else {
        // Null body - reject with SyntaxError
        const exception = @import("webidl").errors.Exception{
            .simple = .{ .type = .SyntaxError, .message = "Unexpected end of JSON input" },
        };
        promise.reject(exception);
    }

    return @ptrCast(promise);
}

/// text() - Returns promise fulfilled with body as string
/// Spec: https://fetch.spec.whatwg.org/#dom-body-text
pub fn call_text(instance: *runtime.Instance) ImplError!*const anyopaque {
    const state = instance.getState(State);
    const internal = state.own._internal.?;

    // Get event loop from context
    const event_loop = instance.ctx.getEventLoop() catch {
        return error.InvalidState;
    };

    // Create AsyncPromise for USVString result
    const AsyncPromise = @import("streams_async_promise").AsyncPromise;
    var promise = try AsyncPromise(runtime.USVString).init(
        internal.allocator,
        event_loop,
    );

    // Check if unusable (step 1 of consume body algorithm)
    if (internal.request.body) |body| {
        switch (body) {
            .bytes => |bytes| {
                // For byte sequence bodies, just convert to string
                // Allocate and return the string
                const text = try internal.allocator.dupe(u8, bytes);
                promise.fulfill(text);
            },
            .body => |body_obj| {
                // Check if body is disturbed or locked (unusable)
                if (body_obj.isDisturbed()) {
                    const exception = @import("webidl").errors.Exception{
                        .simple = .{ .type = .TypeError, .message = "Body is unusable (already read)" },
                    };
                    promise.reject(exception);
                } else {
                    // Read all bytes from body
                    const bytes = body_obj.readAllBytes() catch {
                        const exception = @import("webidl").errors.Exception{
                            .simple = .{ .type = .TypeError, .message = "Failed to read body" },
                        };
                        promise.reject(exception);
                        return @ptrCast(promise);
                    };

                    // Convert to string (allocate copy)
                    const text = try internal.allocator.dupe(u8, bytes);
                    promise.fulfill(text);
                }
            },
        }
    } else {
        // Null body - fulfill with empty string
        const empty = try internal.allocator.alloc(u8, 0);
        promise.fulfill(empty);
    }

    return @ptrCast(promise);
}

// === Helper Functions ===

/// Normalize HTTP method per Fetch spec
/// Uppercases DELETE, GET, HEAD, OPTIONS, POST, PUT
fn normalizeMethod(method: []const u8) []const u8 {
    // Check case-insensitively and return uppercase version
    if (std.ascii.eqlIgnoreCase(method, "DELETE")) return "DELETE";
    if (std.ascii.eqlIgnoreCase(method, "GET")) return "GET";
    if (std.ascii.eqlIgnoreCase(method, "HEAD")) return "HEAD";
    if (std.ascii.eqlIgnoreCase(method, "OPTIONS")) return "OPTIONS";
    if (std.ascii.eqlIgnoreCase(method, "POST")) return "POST";
    if (std.ascii.eqlIgnoreCase(method, "PUT")) return "PUT";
    // Non-standard methods are returned as-is
    return method;
}
