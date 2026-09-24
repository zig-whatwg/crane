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
const abort_algorithms = @import("dom").abort_algorithms;

// Import File API for Blob support
const file = @import("file");
const BlobData = file.BlobData;

// Import Blob WebIDL wrapper
const BlobImpl = @import("Blob.zig");
const webidl = @import("webidl");

// RequestInit is now properly defined in dictionaries with all Fetch spec fields

const Request = interfaces.Request;
const same_object = @import("same_object.zig");

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
    /// Keeps `this.body`'s stream alive for as long as this object - see
    /// `same_object.zig`. (`headers` works the other way round: the Headers
    /// object keeps its owner alive, because its list lives in the owner.)
    body_pin: same_object.Pin = .{},
};

/// Initialize instance
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    // fetch() reads a Request object's request through this hook.
    @import("dom").fetch_objects.installRequest(.{ .request_of = &requestOf });

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
    };

    // Store in instance
    const state = instance.getState(StateType);
    state.own._internal = internal;

    return instance;
}

/// dom.fetch_objects: "requestObject's request". Borrowed.
fn requestOf(request_object: *runtime.Instance) ?*anyopaque {
    const state = request_object.stateAs(State) orelse return null;
    const internal = state.own._internal orelse return null;
    return @ptrCast(internal.request);
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
        // No Headers object can be alive here: a live one pins this request,
        // because its list is `request.header_list` below (Headers.zig,
        // InternalState.Owner). At context teardown the order is arbitrary,
        // which is what that object's generation check is for.
        internal.body_pin.release();

        internal.request.deinit();
        allocator.destroy(internal);
    }
    // NOTE: Do NOT call runtime.Instance.deinit(instance) here!
    // The GC integration layer handles slab freeing after this returns.
}

/// Fetch "append" a header (name, value) to a Headers object whose guard is
/// "request", or "request-no-cors" when `no_cors` - the constructor's "fill"
/// runs it for each pair of init["headers"].
fn appendHeader(allocator: std.mem.Allocator, list: *fetch.internal.HeaderList, name: []const u8, raw_value: []const u8, no_cors: bool) !void {
    const validation = fetch.internal.validation;
    // Step 1: Normalize value (strip leading and trailing HTTP whitespace).
    const value = std.mem.trim(u8, raw_value, " \t\r\n");
    // Step 2: "validate" - an invalid name or value throws; a forbidden
    // request-header is dropped under the "request" guard.
    if (!validation.isValidHeaderName(name) or !validation.isValidHeaderValue(value)) return error.TypeError;
    if (validation.isForbiddenRequestHeader(name, value)) return;
    if (no_cors) {
        // Step 3: under "request-no-cors", the value it would combine to
        // must keep the header no-CORS-safelisted, or nothing is appended.
        const existing = try list.get(allocator, name);
        defer if (existing) |e| allocator.free(e);
        const combined = if (existing) |e| try std.fmt.allocPrint(allocator, "{s}, {s}", .{ e, value }) else try allocator.dupe(u8, value);
        defer allocator.free(combined);
        if (!validation.isNoCORSSafelistedRequestHeader(name, combined)) return;
    }
    // Step 4: Append (name, value) to headers's header list.
    try list.append(name, value);
    // Step 5: under "request-no-cors", remove privileged no-CORS request
    // headers from headers.
    if (no_cors) {
        for ([_][]const u8{"range"}) |privileged| list.delete(privileged);
    }
}

/// This's relevant settings object's API base URL, owned by
/// `ctx.allocator`. A window's is its document's base URL - for an
/// about:srcdoc document, its container's - so a srcdoc frame's
/// `fetch("../x")` resolves as its parent's would; the document's URL alone
/// (about:srcdoc) resolves nothing relative. A worker's is its script URL,
/// which relevantBaseURL answers.
fn apiBaseURL(ctx: runtime.Context) ?[]u8 {
    const v8_engine = @import("v8");
    if (ctx.getEngineContextAs(v8_engine.ffi.Context)) |v8_context| {
        if (v8_engine.context_manager.getWindowForContext(v8_context)) |window| {
            const document = interfaces.Window.get_document(window) catch null;
            if (document) |d| {
                const base = interfaces.Node.get_baseURI(d) catch null;
                if (base) |b| {
                    if (b.len > 0) return @constCast(b);
                    d.ctx.allocator.free(b);
                }
            }
        }
    }
    const url = relevantBaseURL(ctx) orelse return null;
    return ctx.allocator.dupe(u8, url) catch null;
}

/// This's relevant settings object's API base URL.
///
/// Spec: https://html.spec.whatwg.org/multipage/webappapis.html#api-base-url
///
/// The same lookup `XMLHttpRequest.open()` makes (see `relevantBaseURL` in
/// XMLHttpRequest.zig): a Window's navigation records the document URL in the
/// context entry, and a worker records its script URL there
/// (html/worker_v8_context.zig), which is a worker's API base URL. Borrowed;
/// not ours to free.
fn relevantBaseURL(ctx: runtime.Context) ?[]const u8 {
    const v8_engine = @import("v8");
    const v8_context = ctx.getEngineContextAs(v8_engine.ffi.Context) orelse return null;
    const url = v8_engine.context_manager.getDocumentUrl(v8_context) orelse return null;
    if (url.len == 0) return null;
    return url;
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

    // Step 3: Let baseURL be this's relevant settings object's API base URL.
    // Parsed once here; a base that does not parse is no base, under which a
    // relative input fails step 5.2 exactly as it would with no document.
    const api_parser = @import("api_parser");
    var base_record: ?@import("url_record").URLRecord = null;
    defer if (base_record) |*b| b.deinit();
    if (apiBaseURL(ctx)) |base| {
        defer ctx.allocator.free(base);
        base_record = api_parser.parseURL(ctx.allocator, base, null) catch null;
    }

    // Step 4: Let signal be null
    var signal: ?*runtime.Instance = null;

    // Step 5: If input is a string
    switch (input) {
        .usvstring => |url_string| {
            // Step 5.1: Let parsedURL be the result of parsing input with
            // baseURL. This passed no base at all, so every RELATIVE input -
            // `new Request("")`, `new Request("resources/x.py")`, which is how
            // most of fetch/api/request/ builds its requests - failed step 5.2
            // and threw TypeError, from the top level of the test script.
            // Step 5.2: If parsedURL is failure, throw TypeError.
            var parsed_url = api_parser.parseURL(
                ctx.allocator,
                url_string,
                if (base_record) |*b| b else null,
            ) catch {
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
            const input_state = input_request.stateAs(State) orelse return error.TypeError;
            const input_internal = input_state.own._internal orelse return error.TypeError;

            // Step 6.2: Set request to input's request
            // Clone the request
            base_request = try input_internal.request.clone();

            // Step 6.3: Set signal to input's signal.
            signal = input_state.own.signal;
        },
    }
    errdefer base_request.deinit();

    // Step 12: Set request to a new request (copy of base with modifications)
    // For now, we'll modify base_request in place and create the final instance

    // Step 13: If init is not empty
    // Step 10: If init["window"] exists and is non-null, then throw a
    // TypeError. (`window` can only be set to null.)
    if (init_opts.window) |window| switch (window) {
        .null, .undefined => {},
        else => return error.TypeError,
    };

    const init_is_empty = (init_opts.method == null and
        init_opts.window == null and
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

        // Steps 13.2-4, 13.7-8: already the defaults of a request this
        // constructor built.

        // Step 13.5: Set request's referrer to "client". A Request passed as
        // `input` brings its own, which init replaces.
        base_request.setReferrer(.client);

        // Step 13.6: Set request's referrer policy to the empty string.
        base_request.referrer_policy = .empty;
    }

    // Step 14: If init["referrer"] exists, then:
    if (init_opts.referrer) |referrer| {
        if (referrer.len == 0) {
            // Step 14.2: the empty string means "no-referrer".
            base_request.setReferrer(.no_referrer);
        } else {
            // Step 14.3.1: Let parsedReferrer be the result of parsing
            // referrer with baseURL.
            var parsed_referrer = api_parser.parseURL(
                ctx.allocator,
                referrer,
                if (base_record) |*b| b else null,
            ) catch {
                // Step 14.3.2: If parsedReferrer is failure, throw a TypeError.
                return error.TypeError;
            };
            defer parsed_referrer.deinit();

            const serialized = try @import("url_serializer").serialize(ctx.allocator, &parsed_referrer, false);
            defer ctx.allocator.free(serialized);

            // Step 14.3.3: about:client, or another origin than this's
            // relevant settings object's, means "client". The settings
            // object's origin is taken as its API base URL's, which it is for
            // a document or worker created from a network URL.
            const is_about_client = std.mem.eql(u8, parsed_referrer.scheme(), "about") and
                std.mem.startsWith(u8, serialized, "about:client") and
                (serialized.len == "about:client".len or serialized["about:client".len] == '?' or serialized["about:client".len] == '#');
            if (is_about_client or !sameTupleOrigin(serialized, relevantBaseURL(ctx))) {
                base_request.setReferrer(.client);
            } else {
                // Step 14.3.4: Otherwise, set request's referrer to
                // parsedReferrer.
                try base_request.setReferrerUrl(serialized);
            }
        }
    }

    // Step 25: If init["method"] exists
    if (init_opts.method) |method| {
        // Step 25.1: Let method = init["method"]
        // Step 25.2: If method is not a method or method is a forbidden
        // method, then throw a TypeError.
        if (!isMethod(method) or isForbiddenMethod(method)) return error.TypeError;

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

    // Step 32.1: If request's mode is "no-cors" and its method is not a
    // CORS-safelisted method, then throw a TypeError. Checked here, ahead of
    // the headers - both are TypeErrors, and nothing between step 25 and here
    // can throw anything else.
    if (base_request.mode == .no_cors and !isCorsSafelistedMethod(base_request.method)) {
        return error.TypeError;
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
        // Step 32.2: this's headers' guard is "request-no-cors" when the
        // mode is "no-cors", otherwise "request".
        const no_cors = base_request.mode == .no_cors;
        // Step 32.3 / 34: fill this's headers with headers_init - "fill" is
        // Headers' "append" for each pair, under that guard.
        switch (headers_init) {
            .sequence_byte_string_sequence => |outer_seq| {
                // Array of [name, value] pairs: sequence<sequence<ByteString>>
                for (outer_seq) |inner_seq| {
                    // "If header's size is not 2, then throw a TypeError."
                    if (inner_seq.len != 2) return error.TypeError;
                    try appendHeader(ctx.allocator, &base_request.header_list, inner_seq[0], inner_seq[1], no_cors);
                }
            },
            .byte_string_byte_string_record => |entries| {
                // Object with header entries: record<ByteString, ByteString>
                for (entries) |entry| {
                    try appendHeader(ctx.allocator, &base_request.header_list, entry.key, entry.value, no_cors);
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

    // Step 29 (with step 13's "If init["signal"] exists, then set signal to
    // it"): signals is « signal » if signal is non-null; otherwise « ».
    if (init_opts.signal) |init_signal| signal = init_signal;
    const signals: []const *runtime.Instance = if (signal) |s| &.{s} else &.{};
    // Step 30: this's signal is a dependent abort signal from signals.
    state.own.signal = try abort_algorithms.createDependent(ctx, signals);

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

/// An owned copy of `bytes` for a string getter to return.
///
/// OWNERSHIP: a getter returning USVString/ByteString/DOMString has its result
/// FREED by the interface layer (the `needs_cleanup` defer in
/// `engines/v8/interface.zig`), with `instance.ctx.allocator`. The three getters
/// below returned the request's own storage - its method, its URL-list entry,
/// and for `referrer` a string literal - so every read freed memory the request
/// still owned (a double free at `deinit`) or, for the literal, wrote into
/// read-only memory (`Bus error` in `memset`).
fn ownedString(instance: *runtime.Instance, bytes: []const u8) ![]const u8 {
    if (bytes.len == 0) return "";
    return try instance.ctx.allocator.dupe(u8, bytes);
}

/// Get method
/// Spec: https://fetch.spec.whatwg.org/#dom-request-method
pub fn get_method(instance: *runtime.Instance) anyerror!runtime.ByteString {
    const state = instance.getState(State);
    const internal = state.own._internal.?;
    return try ownedString(instance, internal.request.method);
}

/// Get URL
/// Spec: https://fetch.spec.whatwg.org/#dom-request-url
pub fn get_url(instance: *runtime.Instance) anyerror!runtime.USVString {
    const state = instance.getState(State);
    const internal = state.own._internal.?;
    // Use accessor method - returns first URL in url_list
    return try ownedString(instance, internal.request.getUrl());
}

/// Get headers - creates and caches Headers instance on first access
pub fn get_headers(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const state = instance.getState(State);
    const internal = state.own._internal.?;

    // Only reached when the generated getter's `cached_headers` is empty - it
    // is the one cache ([SameObject]). A second cache here used to hold the
    // same pointer where nothing could clear it.
    //
    // The Headers object's list IS this request's header list, by reference,
    // so it keeps this request alive and clears `cached_headers` when it is
    // collected - see Headers.InternalState.Owner.
    const Headers = @import("Headers.zig");
    return Headers.initWithHeaderList(
        internal.allocator,
        instance.ctx,
        &internal.request.header_list,
        .request,
        instance,
        &state.own.cached_headers,
    );
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

    // Spec: https://fetch.spec.whatwg.org/#dom-request-referrer - owned, see
    // `ownedString`.
    return switch (internal.request.referrer) {
        .no_referrer => "",
        .client => try ownedString(instance, "about:client"),
        .url => |url| try ownedString(instance, url),
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
    // `state.own.body` is a pointer V8 cannot see: hold the stream's wrapper
    // for as long as this object, or a collection frees the stream under it.
    internal.body_pin.hold(stream_instance);

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

    // Steps 3-4: clonedRequestObject's signal is a dependent abort signal
    // from « this's signal ».
    cloned_state.own.signal = try abort_algorithms.createDependent(instance.ctx, &.{state.own.signal});

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
/// Is `method` a method - the `token` production of RFC 9110?
///
/// Spec: https://fetch.spec.whatwg.org/#concept-method
fn isMethod(method: []const u8) bool {
    if (method.len == 0) return false;
    for (method) |c| switch (c) {
        '!', '#', '$', '%', '&', '\'', '*', '+', '-', '.', '^', '_', '`', '|', '~' => {},
        '0'...'9', 'a'...'z', 'A'...'Z' => {},
        else => return false,
    };
    return true;
}

/// Spec: https://fetch.spec.whatwg.org/#forbidden-method - CONNECT, TRACE or
/// TRACK, byte-case-insensitively.
fn isForbiddenMethod(method: []const u8) bool {
    return std.ascii.eqlIgnoreCase(method, "CONNECT") or
        std.ascii.eqlIgnoreCase(method, "TRACE") or
        std.ascii.eqlIgnoreCase(method, "TRACK");
}

/// Spec: https://fetch.spec.whatwg.org/#cors-safelisted-method - GET, HEAD or
/// POST. Compared after normalization, so byte-exact.
fn isCorsSafelistedMethod(method: []const u8) bool {
    return std.mem.eql(u8, method, "GET") or std.mem.eql(u8, method, "HEAD") or std.mem.eql(u8, method, "POST");
}

/// Same origin, for two serialized URLs whose origin is a tuple.
///
/// Only http(s) is compared as a tuple - scheme, host, port - which is where
/// referrers come from. Anything else has an opaque origin here and is never
/// same origin, which step 14.3.3 turns into "client": the safe answer. Text
/// comparison is exact because both sides come out of the same serializer.
fn sameTupleOrigin(a: []const u8, b_opt: ?[]const u8) bool {
    const b = b_opt orelse return false;
    const pa = tupleOrigin(a) orelse return false;
    const pb = tupleOrigin(b) orelse return false;
    return std.mem.eql(u8, pa.scheme, pb.scheme) and std.mem.eql(u8, pa.host_port, pb.host_port);
}

const TupleOrigin = struct { scheme: []const u8, host_port: []const u8 };

fn tupleOrigin(serialized: []const u8) ?TupleOrigin {
    const sep = std.mem.indexOf(u8, serialized, "://") orelse return null;
    const scheme = serialized[0..sep];
    if (!std.mem.eql(u8, scheme, "http") and !std.mem.eql(u8, scheme, "https")) return null;
    const rest = serialized[sep + 3 ..];
    const authority = rest[0 .. std.mem.indexOfAny(u8, rest, "/?#") orelse rest.len];
    const host_start = if (std.mem.lastIndexOfScalar(u8, authority, '@')) |at| at + 1 else 0;
    return .{ .scheme = scheme, .host_port = authority[host_start..] };
}

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
