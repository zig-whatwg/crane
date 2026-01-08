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

// Helper to get promise object and destroy handle to prevent memory leaks
fn getPromiseAndCleanup(engine: *const runtime.EngineInterface, promise_handle: *anyopaque, allocator: std.mem.Allocator) runtime.JSValue {
    const promise_obj = engine.getPromiseObject(promise_handle);
    if (engine.destroyPromiseHandle) |destroy| {
        destroy(promise_handle, allocator);
    }
    return runtime.JSValue.fromHandle(promise_obj);
}

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

/// Deinitialize - clean up owned resources only
/// NOTE: Do NOT call runtime.Instance.deinit() here!
/// The GC integration layer (gc_integration.onObjectFreed) handles:
/// 1. Calling this deinit function (via vtable.deinit)
/// 2. Freeing the Instance handle back to the SlabAllocator
/// Calling Instance.deinit from here would cause infinite recursion.
pub fn deinit(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        const allocator = internal.allocator;
        // NOTE: The cached Headers wrapper (if any) was created via initWithHeaderList
        // which sets owns_headers=false. This means Headers.deinit won't free the
        // header strings - Request.request.deinit() will. The Headers instance
        // itself is in the wrapper cache and will be cleaned up by GC.
        // We don't explicitly call Headers.deinit here to avoid order-of-destruction
        // issues - let the wrapper cache handle it.
        internal.headers_cache = null;

        internal.request.deinit();
        allocator.destroy(internal);
    }
    // NOTE: Do NOT call runtime.Instance.deinit(instance) here!
    // The GC integration layer handles slab freeing after this returns.
}

/// Constructor - implements full Request(input, init) constructor algorithm
/// Spec: https://fetch.spec.whatwg.org/#dom-request
pub fn call_constructor(ctx: runtime.Context, input: typedefs.RequestInfo, init_data: webidl.Opt(dictionaries.RequestInit)) !*runtime.Instance {
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
        .usvstring => |url_string| {
            // Step 5.1: Parse URL
            const api_parser = @import("api_parser");

            // Per Fetch spec §5.4, parsedURL is the result of parsing input with
            // the relevant settings object's API base URL. Without a document or
            // worker context (e.g., in REPL), only absolute URLs are valid.
            // Step 5.2: If parsedURL is failure, throw TypeError.
            var parsed_url = api_parser.parseURL(ctx.allocator, url_string, null) catch {
                return error.TypeError;
            };
            defer parsed_url.deinit();

            // Step 5.3: If parsedURL includes credentials, throw TypeError
            if (parsed_url.username().len > 0 or parsed_url.password().len > 0) {
                return error.TypeError;
            }

            // Step 5.4: Create new request with URL
            const url_serializer = @import("url_serializer");
            const serialized_url = try url_serializer.serialize(ctx.allocator, &parsed_url, false);
            defer ctx.allocator.free(serialized_url);

            base_request = try InternalRequest.init(ctx.allocator, serialized_url);

            // Step 5.5: Set fallbackMode to "cors"
            fallback_mode = enums.RequestMode._cors_;
        },
        .request => |input_request| {
            // Step 6: Otherwise (input is a Request object)
            // Step 6.1: Assert input is a Request object
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
        const normalized = normalizeMethod(method);
        // Free the old method and allocate new one
        ctx.allocator.free(base_request.method);
        base_request.method = try ctx.allocator.dupe(u8, normalized);
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
        // Set integrity_metadata - we need to dupe since we're storing on the request
        const integrity_str = switch (integrity) {
            .empty => "",
            .interned => |s| s,
            .owned => |s| s,
        };
        base_request.integrity_metadata = try ctx.allocator.dupe(u8, integrity_str);
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
            .sequence_byte_string_sequence => |outer_seq| {
                // Array of [name, value] pairs: sequence<sequence<ByteString>>
                for (outer_seq) |inner_seq| {
                    if (inner_seq.len >= 2) {
                        try base_request.header_list.append(inner_seq[0], inner_seq[1]);
                    }
                }
            },
            .byte_string_byte_string_record => |entries| {
                // Object with header entries: record<ByteString, ByteString>
                for (entries) |entry| {
                    try base_request.header_list.append(entry.key, entry.value);
                }
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
    const instance = try init(ctx.allocator, State, &Request.vtable, ctx);
    // Note: After this point, instance.deinit will clean up on error

    // Replace the default request with our configured one
    const state = instance.getState(State);
    const internal = state.own._internal.?;
    internal.request.deinit(); // Free the default empty request
    internal.request = base_request; // Transfer ownership

    // Steps 36-42: Handle body from init
    if (init_opts.body) |body_init| {
        // Handle BodyInit union type
        switch (body_init) {
            .readable_stream => |stream_instance| {
                // ReadableStream body - store reference
                // TODO: Implement proper ReadableStream body handling
                _ = stream_instance;
            },
            .xmlhttp_request_body_init => |xhr_body| {
                // Handle XMLHttpRequestBodyInit variants
                switch (xhr_body) {
                    .usvstring => |body_string| {
                        // String body - USVString is []const u8
                        const body_bytes = body_string;
                        if (body_bytes.len > 0) {
                            // Create Body from bytes - Body.fromBytes copies internally,
                            // so no need to dupe first (which would leak)
                            const fetch_body = fetch.internal.Body.fromBytes(ctx.allocator, body_bytes) catch {
                                return instance;
                            };
                            internal.request.body = .{ .body = fetch_body };

                            // Set Content-Type header if not already set
                            const has_content_type = internal.request.header_list.contains("content-type");
                            if (!has_content_type) {
                                internal.request.header_list.append("Content-Type", "text/plain;charset=UTF-8") catch {};
                            }
                        }
                    },
                    .blob => |blob_instance| {
                        // TODO: Implement Blob body handling
                        _ = blob_instance;
                    },
                    .buffer_source => |buffer| {
                        // TODO: Implement BufferSource body handling
                        _ = buffer;
                    },
                    .form_data => |form_instance| {
                        // TODO: Implement FormData body handling
                        _ = form_instance;
                    },
                    .urlsearch_params => |params_instance| {
                        // TODO: Implement URLSearchParams body handling
                        _ = params_instance;
                    },
                }
            },
        }
    }

    return instance;
}

// === Property Getters ===

/// Get method
pub fn get_method(instance: *runtime.Instance) anyerror!runtime.ByteString {
    const state = instance.getState(State);
    const internal = state.own._internal.?;
    return internal.request.method;
}

/// Get URL
pub fn get_url(instance: *runtime.Instance) anyerror!runtime.USVString {
    const state = instance.getState(State);
    const internal = state.own._internal.?;
    // Use accessor method - returns first URL in url_list
    return internal.request.getUrl();
}

/// Get headers - creates and caches Headers instance on first access
pub fn get_headers(instance: *runtime.Instance) anyerror!*runtime.Instance {
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
pub fn get_destination(instance: *runtime.Instance) anyerror!enums.RequestDestination {
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
pub fn get_referrer(instance: *runtime.Instance) anyerror!runtime.USVString {
    const state = instance.getState(State);
    const internal = state.own._internal.?;

    return switch (internal.request.referrer) {
        .no_referrer => "",
        .client => "about:client",
        .url => |url| url,
    };
}

/// Get referrerPolicy
pub fn get_referrerPolicy(instance: *runtime.Instance) anyerror!enums.ReferrerPolicy {
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
pub fn get_mode(instance: *runtime.Instance) anyerror!enums.RequestMode {
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
pub fn get_credentials(instance: *runtime.Instance) anyerror!enums.RequestCredentials {
    const state = instance.getState(State);
    const internal = state.own._internal.?;

    return switch (internal.request.credentials_mode) {
        .omit => ._omit_,
        .same_origin => ._same_origin_,
        .include => ._include_,
    };
}

/// Get cache
pub fn get_cache(instance: *runtime.Instance) anyerror!enums.RequestCache {
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
pub fn get_redirect(instance: *runtime.Instance) anyerror!enums.RequestRedirect {
    const state = instance.getState(State);
    const internal = state.own._internal.?;

    return switch (internal.request.redirect_mode) {
        .follow => ._follow_,
        .@"error" => ._error_,
        .manual => ._manual_,
    };
}

/// Get integrity
/// Note: Returns owned DOMString - interface layer will free after V8 conversion.
pub fn get_integrity(instance: *runtime.Instance) anyerror!runtime.DOMString {
    const state = instance.getState(State);
    const internal = state.own._internal.?;

    // integrity_metadata is []const u8, convert to DOMString
    if (internal.request.integrity_metadata.len == 0) {
        return runtime.DOMString.initEmpty();
    }
    return try runtime.DOMString.initDupe(instance.ctx.allocator, internal.request.integrity_metadata);
}

/// Get keepalive
pub fn get_keepalive(instance: *runtime.Instance) anyerror!bool {
    const state = instance.getState(State);
    const internal = state.own._internal.?;

    return internal.request.keepalive;
}

/// Get isReloadNavigation
pub fn get_isReloadNavigation(instance: *runtime.Instance) anyerror!bool {
    const state = instance.getState(State);
    const internal = state.own._internal.?;

    return internal.request.reload_navigation;
}

/// Get isHistoryNavigation
pub fn get_isHistoryNavigation(instance: *runtime.Instance) anyerror!bool {
    const state = instance.getState(State);
    const internal = state.own._internal.?;

    return internal.request.history_navigation;
}

/// Get signal - Return from state field
pub fn get_signal(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const state = instance.getState(State);
    return state.own.signal;
}

/// Get duplex
pub fn get_duplex(instance: *runtime.Instance) anyerror!enums.RequestDuplex {
    _ = instance;
    // TODO (Option B): Track duplex mode in InternalRequest
    return ._half_;
}

/// Get targetAddressSpace
pub fn get_targetAddressSpace(instance: *runtime.Instance) anyerror!enums.IPAddressSpace {
    _ = instance;
    // TODO (Option B): Implement target address space from InternalRequest
    return ._public_; // Default to public
}

// === Body Mixin Properties ===

/// Get body
/// Per Fetch spec: returns the body as a ReadableStream, or null if no body
///
/// Note: Currently returns cached stream if available, otherwise attempts to
/// create a ReadableStream from internal body data. Falls back to null if
/// stream creation is not possible (e.g., no event loop).
pub fn get_body(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    const state = instance.getState(State);
    const internal = state.own._internal.?;

    // If we already have a cached ReadableStream, return it
    if (state.own.body) |cached_body| {
        return cached_body;
    }

    // Check if there's body data
    const has_body = if (internal.request.body) |body| blk: {
        switch (body) {
            .bytes => |bytes| break :blk bytes.len > 0,
            .body => |body_obj| break :blk body_obj.data.items.len > 0 or body_obj.source != .none,
        }
    } else false;

    if (!has_body) {
        return null;
    }

    // Try to create a ReadableStream from the body data
    // This requires an event loop; if not available, return null
    // (body methods like text()/json() will still work directly)
    const ctx = instance.ctx;

    // Check if we have an event loop
    _ = ctx.getOptionalEventLoop() orelse {
        // No event loop, can't create ReadableStream
        // Body methods will still work via direct data access
        return null;
    };

    // Create a basic ReadableStream (use interface per Golden Rule #13)
    // For now, create a simple stream that will serve the body data
    const stream_instance = interfaces.ReadableStream.call_constructor(
        ctx,
        webidl.Opt(runtime.JSValue).notPassed(),
        webidl.Opt(dictionaries.QueuingStrategy).notPassed(),
    ) catch {
        // Stream creation failed, fall back to null
        return null;
    };

    // Cache the stream for future calls
    // Note: This modifies state, which is mutable through the instance
    @constCast(&state.own).body = stream_instance;

    return stream_instance;
}

/// Get bodyUsed
/// Per Fetch spec: true if body has been read/disturbed
pub fn get_bodyUsed(instance: *runtime.Instance) anyerror!bool {
    const state = instance.getState(State);
    const internal = state.own._internal.?;

    // Check internal body state
    if (internal.request.body) |body| {
        switch (body) {
            .bytes => return false, // Raw bytes are never "used"
            .body => |body_obj| return body_obj.isUsed(),
        }
    }
    return false;
}

// === Methods - STUBS (Option A) ===

/// clone() - Clones the Request
/// Spec: https://fetch.spec.whatwg.org/#dom-request-clone
pub fn call_clone(instance: *runtime.Instance) anyerror!*runtime.Instance {
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
///
/// Uses the engine abstraction layer for Promise and ArrayBuffer creation.
pub fn call_arrayBuffer(instance: *runtime.Instance) anyerror!runtime.JSValue {
    const state = instance.getState(State);
    const internal = state.own._internal.?;

    // Get the engine interface and context
    const engine = instance.ctx.engine orelse {
        return error.InvalidState;
    };
    const engine_ctx = instance.ctx.engine_ctx orelse {
        return error.InvalidState;
    };

    // Create a Promise through the engine abstraction
    const promise_handle = engine.createPromise(engine_ctx, internal.allocator) catch {
        return error.InvalidState;
    };

    // Check for disturbed body (already read)
    if (internal.request.body) |body| {
        switch (body) {
            .bytes => {},
            .body => |body_obj| {
                if (body_obj.isDisturbed()) {
                    // Reject with TypeError per spec
                    engine.rejectPromise(engine_ctx, promise_handle, error.TypeError) catch {};
                    return getPromiseAndCleanup(engine, promise_handle, internal.allocator);
                }
            },
        }
    }

    // Get body bytes
    const body_bytes: []const u8 = if (internal.request.body) |body| blk: {
        switch (body) {
            .bytes => |bytes| break :blk bytes,
            .body => |body_obj| {
                const bytes = body_obj.readAllBytes() catch |err| {
                    // Reject on read error
                    engine.rejectPromise(engine_ctx, promise_handle, err) catch {};
                    return getPromiseAndCleanup(engine, promise_handle, internal.allocator);
                };
                break :blk bytes;
            },
        }
    } else "";

    // Create JS ArrayBuffer through engine abstraction
    const createArrayBuffer = engine.createArrayBuffer orelse {
        // No createArrayBuffer support - reject with error
        engine.rejectPromise(engine_ctx, promise_handle, error.InvalidState) catch {};
        return getPromiseAndCleanup(engine, promise_handle, internal.allocator);
    };

    const js_array_buffer = createArrayBuffer(engine_ctx, body_bytes) catch {
        engine.rejectPromise(engine_ctx, promise_handle, error.InvalidState) catch {};
        return getPromiseAndCleanup(engine, promise_handle, internal.allocator);
    };

    // Resolve with the JS ArrayBuffer
    engine.resolvePromise(engine_ctx, promise_handle, js_array_buffer) catch {
        return error.InvalidState;
    };

    // Return the JS Promise object wrapped in Promise(T) type
    return getPromiseAndCleanup(engine, promise_handle, internal.allocator);
}

/// blob() - Returns promise fulfilled with body as Blob
/// Spec: https://fetch.spec.whatwg.org/#dom-body-blob
///
/// Uses the engine abstraction layer for Promise creation and instance wrapping.
pub fn call_blob(instance: *runtime.Instance) anyerror!runtime.JSValue {
    const state = instance.getState(State);
    const internal = state.own._internal.?;

    // Get the engine interface and context
    const engine = instance.ctx.engine orelse {
        return error.InvalidState;
    };
    const engine_ctx = instance.ctx.engine_ctx orelse {
        return error.InvalidState;
    };

    // Create a Promise through the engine abstraction
    const promise_handle = engine.createPromise(engine_ctx, internal.allocator) catch {
        return error.InvalidState;
    };

    // Get MIME type from Content-Type header
    const mime_type = blk: {
        const ct = internal.request.header_list.get(internal.allocator, "content-type") catch null;
        break :blk ct orelse "";
    };

    // Check for disturbed body (already read)
    if (internal.request.body) |body| {
        switch (body) {
            .bytes => {},
            .body => |body_obj| {
                if (body_obj.isDisturbed()) {
                    // Reject with TypeError per spec
                    engine.rejectPromise(engine_ctx, promise_handle, error.TypeError) catch {};
                    return getPromiseAndCleanup(engine, promise_handle, internal.allocator);
                }
            },
        }
    }

    // Get body bytes
    const body_bytes: []const u8 = if (internal.request.body) |body| blk: {
        switch (body) {
            .bytes => |bytes| break :blk bytes,
            .body => |body_obj| {
                const bytes = body_obj.readAllBytes() catch |err| {
                    // Reject on read error
                    engine.rejectPromise(engine_ctx, promise_handle, err) catch {};
                    return getPromiseAndCleanup(engine, promise_handle, internal.allocator);
                };
                break :blk bytes;
            },
        }
    } else "";

    // Create Blob instance
    const blob_data = BlobData.init(internal.allocator, body_bytes, mime_type) catch {
        engine.rejectPromise(engine_ctx, promise_handle, error.OutOfMemory) catch {};
        return getPromiseAndCleanup(engine, promise_handle, internal.allocator);
    };

    const blob_instance = BlobImpl.createFromBlobData(
        internal.allocator,
        instance.ctx,
        blob_data,
    ) catch {
        blob_data.deinit();
        engine.rejectPromise(engine_ctx, promise_handle, error.OutOfMemory) catch {};
        return getPromiseAndCleanup(engine, promise_handle, internal.allocator);
    };

    // Wrap the Blob instance as a V8 object
    const wrapInstance = engine.wrapInstance orelse {
        engine.rejectPromise(engine_ctx, promise_handle, error.InvalidState) catch {};
        return getPromiseAndCleanup(engine, promise_handle, internal.allocator);
    };

    const js_blob = wrapInstance(engine_ctx, blob_instance) catch {
        engine.rejectPromise(engine_ctx, promise_handle, error.InvalidState) catch {};
        return getPromiseAndCleanup(engine, promise_handle, internal.allocator);
    };

    // Resolve with the JS Blob
    engine.resolvePromise(engine_ctx, promise_handle, js_blob) catch {
        return error.InvalidState;
    };

    // Return the JS Promise object wrapped in Promise(T) type
    return getPromiseAndCleanup(engine, promise_handle, internal.allocator);
}

/// bytes() - Returns promise fulfilled with body as Uint8Array
/// Spec: https://fetch.spec.whatwg.org/#dom-body-bytes
///
/// Uses the engine abstraction layer for Promise and Uint8Array creation.
pub fn call_bytes(instance: *runtime.Instance) anyerror!runtime.JSValue {
    const state = instance.getState(State);
    const internal = state.own._internal.?;

    // Get the engine interface and context
    const engine = instance.ctx.engine orelse {
        return error.InvalidState;
    };
    const engine_ctx = instance.ctx.engine_ctx orelse {
        return error.InvalidState;
    };

    // Create a Promise through the engine abstraction
    const promise_handle = engine.createPromise(engine_ctx, internal.allocator) catch {
        return error.InvalidState;
    };

    // Check for disturbed body (already read)
    if (internal.request.body) |body| {
        switch (body) {
            .bytes => {},
            .body => |body_obj| {
                if (body_obj.isDisturbed()) {
                    // Reject with TypeError per spec
                    engine.rejectPromise(engine_ctx, promise_handle, error.TypeError) catch {};
                    return getPromiseAndCleanup(engine, promise_handle, internal.allocator);
                }
            },
        }
    }

    // Get body bytes
    const body_bytes: []const u8 = if (internal.request.body) |body| blk: {
        switch (body) {
            .bytes => |bytes| break :blk bytes,
            .body => |body_obj| {
                const bytes = body_obj.readAllBytes() catch |err| {
                    // Reject on read error
                    engine.rejectPromise(engine_ctx, promise_handle, err) catch {};
                    return getPromiseAndCleanup(engine, promise_handle, internal.allocator);
                };
                break :blk bytes;
            },
        }
    } else "";

    // Create JS Uint8Array through engine abstraction
    const createUint8Array = engine.createUint8Array orelse {
        // No createUint8Array support - reject with error
        engine.rejectPromise(engine_ctx, promise_handle, error.InvalidState) catch {};
        return getPromiseAndCleanup(engine, promise_handle, internal.allocator);
    };

    const js_uint8_array = createUint8Array(engine_ctx, body_bytes) catch {
        engine.rejectPromise(engine_ctx, promise_handle, error.InvalidState) catch {};
        return getPromiseAndCleanup(engine, promise_handle, internal.allocator);
    };

    // Resolve with the JS Uint8Array
    engine.resolvePromise(engine_ctx, promise_handle, js_uint8_array) catch {
        return error.InvalidState;
    };

    // Return the JS Promise object wrapped in Promise(T) type
    return getPromiseAndCleanup(engine, promise_handle, internal.allocator);
}

/// formData() - Returns promise fulfilled with body as FormData
/// Spec: https://fetch.spec.whatwg.org/#dom-body-formdata
///
/// Uses the engine abstraction layer for Promise creation and instance wrapping.
pub fn call_formData(instance: *runtime.Instance) anyerror!runtime.JSValue {
    const state = instance.getState(State);
    const internal = state.own._internal.?;

    // Get the engine interface and context
    const engine = instance.ctx.engine orelse {
        return error.InvalidState;
    };
    const engine_ctx = instance.ctx.engine_ctx orelse {
        return error.InvalidState;
    };

    // Create a Promise through the engine abstraction
    const promise_handle = engine.createPromise(engine_ctx, internal.allocator) catch {
        return error.InvalidState;
    };

    const FormDataImpl = @import("FormData.zig");
    const xhr = @import("xhr");
    const multipart_parser = xhr.multipart_parser;
    const url_parser = @import("form_parser");

    // Helper to reject with error (uses module-level getPromiseAndCleanup)
    const rejectAndReturn = struct {
        fn call(eng: anytype, eng_ctx: anytype, handle: anytype, err: anyerror, alloc: std.mem.Allocator) runtime.JSValue {
            eng.rejectPromise(eng_ctx, handle, err) catch {};
            return getPromiseAndCleanup(eng, handle, alloc);
        }
    }.call;

    // Get Content-Type header
    const content_type = internal.request.header_list.get(internal.allocator, "content-type") catch null;
    defer if (content_type) |ct| internal.allocator.free(ct);

    // Check for disturbed body (already read)
    if (internal.request.body) |body| {
        switch (body) {
            .bytes => {},
            .body => |body_obj| {
                if (body_obj.isDisturbed()) {
                    return rejectAndReturn(engine, engine_ctx, promise_handle, error.TypeError, internal.allocator);
                }
            },
        }
    }

    // Get body bytes
    const body_bytes: []const u8 = if (internal.request.body) |body| blk: {
        switch (body) {
            .bytes => |bytes| break :blk bytes,
            .body => |body_obj| {
                const bytes = body_obj.readAllBytes() catch {
                    return rejectAndReturn(engine, engine_ctx, promise_handle, error.TypeError, internal.allocator);
                };
                break :blk bytes;
            },
        }
    } else "";

    // Parse body into FormData based on Content-Type
    const form_data: *xhr.form_data.FormData = if (body_bytes.len > 0) parse_blk: {
        if (content_type) |ct| {
            if (std.mem.indexOf(u8, ct, "multipart/form-data") != null) {
                // Extract boundary and parse multipart
                const boundary = multipart_parser.extractBoundary(internal.allocator, ct) catch {
                    return rejectAndReturn(engine, engine_ctx, promise_handle, error.TypeError, internal.allocator);
                };
                defer internal.allocator.free(boundary);

                const entries = multipart_parser.parseMultipartFormData(internal.allocator, body_bytes, boundary) catch {
                    return rejectAndReturn(engine, engine_ctx, promise_handle, error.TypeError, internal.allocator);
                };
                defer {
                    for (entries) |*entry| entry.deinit(internal.allocator);
                    internal.allocator.free(entries);
                }

                const fd = xhr.form_data.FormData.init(internal.allocator) catch {
                    return rejectAndReturn(engine, engine_ctx, promise_handle, error.OutOfMemory, internal.allocator);
                };
                errdefer fd.deinit();

                for (entries) |entry| {
                    switch (entry.value) {
                        .string => |s| fd.appendString(entry.name, s) catch {
                            return rejectAndReturn(engine, engine_ctx, promise_handle, error.OutOfMemory, internal.allocator);
                        },
                        .file => |f| fd.appendFile(entry.name, f, entry.filename) catch {
                            return rejectAndReturn(engine, engine_ctx, promise_handle, error.OutOfMemory, internal.allocator);
                        },
                        .blob_instance => |ptr| fd.appendBlobInstance(entry.name, ptr, entry.filename) catch {
                            return rejectAndReturn(engine, engine_ctx, promise_handle, error.OutOfMemory, internal.allocator);
                        },
                    }
                }

                break :parse_blk fd;
            } else if (std.mem.indexOf(u8, ct, "application/x-www-form-urlencoded") != null) {
                // Parse URL-encoded
                const tuples = url_parser.parse(internal.allocator, body_bytes) catch {
                    return rejectAndReturn(engine, engine_ctx, promise_handle, error.TypeError, internal.allocator);
                };
                defer {
                    for (tuples) |tuple| tuple.deinit(internal.allocator);
                    internal.allocator.free(tuples);
                }

                const fd = xhr.form_data.FormData.init(internal.allocator) catch {
                    return rejectAndReturn(engine, engine_ctx, promise_handle, error.OutOfMemory, internal.allocator);
                };
                errdefer fd.deinit();

                for (tuples) |tuple| {
                    fd.appendString(tuple.name, tuple.value) catch {
                        return rejectAndReturn(engine, engine_ctx, promise_handle, error.OutOfMemory, internal.allocator);
                    };
                }

                break :parse_blk fd;
            } else {
                // Invalid Content-Type
                return rejectAndReturn(engine, engine_ctx, promise_handle, error.TypeError, internal.allocator);
            }
        } else {
            // No Content-Type header - default to URL-encoded
            const tuples = url_parser.parse(internal.allocator, body_bytes) catch {
                return rejectAndReturn(engine, engine_ctx, promise_handle, error.TypeError, internal.allocator);
            };
            defer {
                for (tuples) |tuple| tuple.deinit(internal.allocator);
                internal.allocator.free(tuples);
            }

            const fd = xhr.form_data.FormData.init(internal.allocator) catch {
                return rejectAndReturn(engine, engine_ctx, promise_handle, error.OutOfMemory, internal.allocator);
            };
            errdefer fd.deinit();

            for (tuples) |tuple| {
                fd.appendString(tuple.name, tuple.value) catch {
                    return rejectAndReturn(engine, engine_ctx, promise_handle, error.OutOfMemory, internal.allocator);
                };
            }

            break :parse_blk fd;
        }
    } else empty_blk: {
        // Empty body - create empty FormData
        break :empty_blk xhr.form_data.FormData.init(internal.allocator) catch {
            return rejectAndReturn(engine, engine_ctx, promise_handle, error.OutOfMemory, internal.allocator);
        };
    };

    // Create FormData WebIDL instance
    const formdata_instance = FormDataImpl.createFromInternal(
        internal.allocator,
        instance.ctx,
        form_data,
    ) catch {
        form_data.deinit();
        return rejectAndReturn(engine, engine_ctx, promise_handle, error.OutOfMemory, internal.allocator);
    };

    // Wrap the FormData instance as a V8 object
    const wrapInstance = engine.wrapInstance orelse {
        return rejectAndReturn(engine, engine_ctx, promise_handle, error.InvalidState, internal.allocator);
    };

    const js_formdata = wrapInstance(engine_ctx, formdata_instance) catch {
        return rejectAndReturn(engine, engine_ctx, promise_handle, error.InvalidState, internal.allocator);
    };

    // Resolve with the JS FormData
    engine.resolvePromise(engine_ctx, promise_handle, js_formdata) catch {
        return error.InvalidState;
    };

    // Return the JS Promise object wrapped in Promise(T) type
    return getPromiseAndCleanup(engine, promise_handle, internal.allocator);
}

/// json() - Returns promise fulfilled with body parsed as JSON
/// Spec: https://fetch.spec.whatwg.org/#dom-body-json
///
/// Uses the engine abstraction layer for Promise and JSON parsing.
pub fn call_json(instance: *runtime.Instance) anyerror!runtime.JSValue {
    const state = instance.getState(State);
    const internal = state.own._internal.?;

    // Get the engine interface and context
    const engine = instance.ctx.engine orelse {
        return error.InvalidState;
    };
    const engine_ctx = instance.ctx.engine_ctx orelse {
        return error.InvalidState;
    };

    // Create a Promise through the engine abstraction
    const promise_handle = engine.createPromise(engine_ctx, internal.allocator) catch {
        return error.InvalidState;
    };

    // Check for disturbed body (already read)
    if (internal.request.body) |body| {
        switch (body) {
            .bytes => {},
            .body => |body_obj| {
                if (body_obj.isDisturbed()) {
                    // Reject with TypeError per spec
                    engine.rejectPromise(engine_ctx, promise_handle, error.TypeError) catch {};
                    return getPromiseAndCleanup(engine, promise_handle, internal.allocator);
                }
            },
        }
    }

    // Get body bytes
    const body_bytes: []const u8 = if (internal.request.body) |body| blk: {
        switch (body) {
            .bytes => |bytes| break :blk bytes,
            .body => |body_obj| {
                const bytes = body_obj.readAllBytes() catch |err| {
                    // Reject on read error
                    engine.rejectPromise(engine_ctx, promise_handle, err) catch {};
                    return getPromiseAndCleanup(engine, promise_handle, internal.allocator);
                };
                break :blk bytes;
            },
        }
    } else {
        // Null body - reject with SyntaxError (empty JSON is invalid)
        engine.rejectPromise(engine_ctx, promise_handle, error.SyntaxError) catch {};
        return getPromiseAndCleanup(engine, promise_handle, internal.allocator);
    };

    // Parse JSON through engine abstraction
    const parseJson = engine.parseJson orelse {
        // No parseJson support - reject with error
        engine.rejectPromise(engine_ctx, promise_handle, error.InvalidState) catch {};
        return getPromiseAndCleanup(engine, promise_handle, internal.allocator);
    };

    const js_value = parseJson(engine_ctx, body_bytes) catch {
        // JSON parse failed - reject with SyntaxError
        engine.rejectPromise(engine_ctx, promise_handle, error.SyntaxError) catch {};
        return getPromiseAndCleanup(engine, promise_handle, internal.allocator);
    };

    // Resolve with the parsed JS value
    engine.resolvePromise(engine_ctx, promise_handle, js_value) catch {
        return error.InvalidState;
    };

    // Return the JS Promise object wrapped in Promise(T) type
    return getPromiseAndCleanup(engine, promise_handle, internal.allocator);
}

/// text() - Returns promise fulfilled with body as string
/// Spec: https://fetch.spec.whatwg.org/#dom-body-text
///
/// Uses the engine abstraction layer for Promise creation and string creation.
pub fn call_text(instance: *runtime.Instance) anyerror!runtime.JSValue {
    const state = instance.getState(State);
    const internal = state.own._internal.?;

    // Get the engine interface and context
    const engine = instance.ctx.engine orelse {
        return error.InvalidState;
    };
    const engine_ctx = instance.ctx.engine_ctx orelse {
        return error.InvalidState;
    };

    // Create a Promise through the engine abstraction
    const promise_handle = engine.createPromise(engine_ctx, internal.allocator) catch {
        return error.InvalidState;
    };

    // Check for disturbed body (already read)
    if (internal.request.body) |body| {
        switch (body) {
            .bytes => {},
            .body => |body_obj| {
                if (body_obj.isDisturbed()) {
                    // Reject with TypeError per spec
                    engine.rejectPromise(engine_ctx, promise_handle, error.TypeError) catch {};
                    return getPromiseAndCleanup(engine, promise_handle, internal.allocator);
                }
            },
        }
    }

    // Get body text
    const body_text: []const u8 = if (internal.request.body) |body| blk: {
        switch (body) {
            .bytes => |bytes| break :blk bytes,
            .body => |body_obj| {
                const bytes = body_obj.readAllBytes() catch |err| {
                    // Reject on read error
                    engine.rejectPromise(engine_ctx, promise_handle, err) catch {};
                    return getPromiseAndCleanup(engine, promise_handle, internal.allocator);
                };
                break :blk bytes;
            },
        }
    } else "";

    // Create JS string through engine abstraction
    const createString = engine.createString orelse {
        // No createString support - resolve with null (undefined)
        engine.resolvePromise(engine_ctx, promise_handle, null) catch {};
        return getPromiseAndCleanup(engine, promise_handle, internal.allocator);
    };

    const js_string = createString(engine_ctx, body_text) catch {
        engine.rejectPromise(engine_ctx, promise_handle, error.InvalidState) catch {};
        return getPromiseAndCleanup(engine, promise_handle, internal.allocator);
    };

    // Resolve with the JS string
    engine.resolvePromise(engine_ctx, promise_handle, js_string) catch {
        return error.InvalidState;
    };

    // Return the JS Promise object wrapped in Promise(T) type
    return getPromiseAndCleanup(engine, promise_handle, internal.allocator);
}

// === Helper Functions ===

/// Get URL from instance (for internal use by other impls)
/// Used by Cache.zig and CacheStorage.zig
pub fn getUrlInternal(instance: *runtime.Instance) ?[]const u8 {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return null;
    return internal.request.getUrl();
}

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
