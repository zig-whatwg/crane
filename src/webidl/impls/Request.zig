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
const fetch_body = @import("fetch_body.zig");

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
    /// Keeps `this.body`'s stream alive for as long as this object - see
    /// `same_object.zig`. (`headers` works the other way round: the Headers
    /// object keeps its owner alive, because its list lives in the owner.)
    body_pin: same_object.Pin = .{},
    /// Keeps `this.signal` alive for as long as this object: the getter
    /// returns this's signal, one object for the Request's whole life, and
    /// `state.own.signal` is a pointer V8 cannot see (Blink's Request traces
    /// its signal_). Unpinned when this object goes, the signal is the wrapper
    /// cache's - a fetch() still using it holds its own pin.
    signal_pin: same_object.Pin = .{},
};

/// Initialize instance
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    // fetch() reads a Request object's request through this hook.
    @import("dom").fetch_objects.installRequest(.{ .request_of = &requestOf, .body_stream = &bodyStreamToSend });

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
        internal.signal_pin.release();

        internal.request.deinit();
        allocator.destroy(internal);
    }
    // NOTE: Do NOT call runtime.Instance.deinit(instance) here!
    // The GC integration layer handles slab freeing after this returns.
}

/// This's relevant settings object's API base URL, owned by
/// `ctx.allocator`. A window's is its document's base URL - for an
/// about:srcdoc document, its container's - so a srcdoc frame's
/// `fetch("../x")` resolves as its parent's would; the document's URL alone
/// (about:srcdoc) resolves nothing relative. A worker's is its script URL,
/// which relevantBaseURL answers.
fn apiBaseURL(ctx: runtime.Context) ?[]u8 {
    if (relevantWindow(ctx)) |window| {
        const document = interfaces.Window.get_document(window) catch null;
        if (document) |d| {
            const base = interfaces.Node.get_baseURI(d) catch null;
            if (base) |b| {
                if (b.len > 0) return @constCast(b);
                d.ctx.allocator.free(b);
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
/// XMLHttpRequest.zig): a Window's navigation records the document URL as
/// its realm's document URL, and a worker records its script URL there,
/// which is a worker's API base URL. Borrowed; not ours to free.
fn relevantBaseURL(ctx: runtime.Context) ?[]const u8 {
    const url = ctx.documentUrl() orelse return null;
    if (url.len == 0) return null;
    return url;
}

/// The realm's global object, when it is a Window.
fn relevantWindow(ctx: runtime.Context) ?*runtime.Instance {
    const record = ctx.getRealm() orelse return null;
    const raw = record.global_object orelse return null;
    const global: *runtime.Instance = @ptrCast(@alignCast(raw));
    if (!std.mem.eql(u8, global.vtable.name, "Window")) return null;
    return global;
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
    // The request is this function's until the instance takes it below.
    var base_request_owned = true;
    errdefer if (base_request_owned) base_request.deinit();

    // Step 12: Set request to a new request (copy of base with modifications)
    // For now, we'll modify base_request in place and create the final instance
    // - whose unsafe-request flag is set: script made it, so main fetch
    // step 12 asks a CORS-preflight fetch for a cross-origin request with a
    // method or headers that are not CORS-safelisted.
    base_request.unsafe_request = true;

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
        const guard: fetch.internal.HeaderGuard = if (base_request.mode == .no_cors) .request_no_cors else .request;
        // Step 32.3 / 34: fill this's headers with headers_init - "fill" is
        // Headers' "append" for each pair, under that guard.
        const headers_class = fetch.webidl.headers;
        switch (headers_init) {
            .sequence_byte_string_sequence => |outer_seq| {
                try headers_class.fillFromSequence(ctx.allocator, &base_request.header_list, guard, outer_seq);
            },
            .byte_string_byte_string_record => |entries| {
                for (entries) |entry| {
                    try headers_class.append(ctx.allocator, &base_request.header_list, guard, entry.key, entry.value);
                }
            },
        }
    }

    // Step 34: inputBody is input's request's body if input is a Request
    // object; otherwise null.
    const input_request: ?*runtime.Instance = switch (input) {
        .request => |r| r,
        .usvstring => null,
    };
    const input_has_body = if (input_request) |r| (if (bodyOwner(r)) |o| o.body != null else false) else false;

    // Step 35: If either init["body"] exists and is non-null or inputBody is
    // non-null, and request's method is `GET` or `HEAD`, then throw a
    // TypeError.
    const has_init_body = init_opts.body != null;
    const method_is_get_or_head = std.mem.eql(u8, base_request.method, "GET") or
        std.mem.eql(u8, base_request.method, "HEAD");

    if ((has_init_body or input_has_body) and method_is_get_or_head) {
        return error.TypeError;
    }

    // Step 41.1, checked before anything is made: if initBody is null and
    // inputBody is non-null, and inputBody is unusable, throw a TypeError.
    if (!has_init_body and input_has_body) {
        if (fetch_body.isUnusable(bodyOwner(input_request.?).?)) return error.TypeError;
    }

    // Now create the instance with the configured request
    const instance = try init(ctx.allocator, State, &Request.vtable, ctx);
    // Note: After this point, instance.deinit will clean up on error

    // Replace the default request with our configured one
    const state = instance.getState(State);
    const internal = state.own._internal.?;
    internal.request.deinit(); // Free the default empty request
    internal.request = base_request; // Transfer ownership
    base_request_owned = false;
    // A step below that throws leaves an object nobody has wrapped: free it,
    // and the request with it. (The duplex check on a stream body used to
    // leak its InternalState here.)
    errdefer runtime.Instance.deinit(instance);

    // Step 29 (with step 13's "If init["signal"] exists, then set signal to
    // it"): signals is « signal » if signal is non-null; otherwise « ».
    if (init_opts.signal) |init_signal| signal = init_signal;
    const signals: []const *runtime.Instance = if (signal) |s| &.{s} else &.{};
    // Step 30: this's signal is a dependent abort signal from signals.
    state.own.signal = try abort_algorithms.createDependent(ctx, signals);
    internal.signal_pin.hold(state.own.signal);

    // Steps 36-37: If init["body"] exists and is non-null, initBody is the
    // body of extracting it, with keepalive set to request's keepalive, and
    // its type is appended as `Content-Type` unless the headers have one.
    if (init_opts.body) |body_init| {
        var extracted = fetch_body.extract(ctx.allocator, body_init, internal.request.keepalive) catch |err| return switch (err) {
            error.OutOfMemory => error.OutOfMemory,
            error.TypeError => error.TypeError,
        };
        defer extracted.deinit();

        if (extracted.stream) |stream| {
            // Step 39: a body with a null source - a stream - needs
            // init["duplex"], and a same-origin or CORS request, and sets
            // the use-CORS-preflight flag.
            if (init_opts.duplex == null) return error.TypeError;
            if (internal.request.mode != .same_origin and internal.request.mode != .cors) return error.TypeError;
            internal.request.use_cors_preflight = true;
            // The body's stream is the object itself.
            state.own.body = stream;
            internal.body_pin.hold(stream);
        }

        // Step 42: Set this's request's body to finalBody. (Replacing the
        // input request's, which the request copy above carried over.)
        if (extracted.takeBody()) |b| {
            if (internal.request.body) |old_body| switch (old_body) {
                .body => |ob| ob.deinit(),
                .bytes => {},
            };
            internal.request.body = .{ .body = b };
        }

        if (extracted.content_type) |content_type| {
            if (!internal.request.header_list.contains("Content-Type")) {
                try internal.request.header_list.append("Content-Type", content_type);
            }
        }
    }

    // Step 41.2: if initBody is null and inputBody is non-null, finalBody is
    // a proxy for inputBody: input's body's stream is piped into it, so
    // input's body is locked and disturbed from here on.
    if (!has_init_body and input_has_body) {
        try fetch_body.proxyInto(bodyOwner(input_request.?).?, bodyOwner(instance).?);
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
    //
    // Its guard is "request", or "request-no-cors" for a no-cors request
    // (constructor step 32.2; the mode cannot change after).
    const Headers = @import("Headers.zig");
    return Headers.initWithHeaderList(
        internal.allocator,
        instance.ctx,
        &internal.request.header_list,
        if (internal.request.mode == .no_cors) .request_no_cors else .request,
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
    const o = bodyOwner(instance) orelse return null;
    return fetch_body.bodyStream(o);
}

/// Get bodyUsed
/// Per Fetch spec: true if body has been read/disturbed
pub fn get_bodyUsed(instance: *runtime.Instance) anyerror!bool {
    const o = bodyOwner(instance) orelse return false;
    return fetch_body.bodyUsed(o);
}

// ============================================================================
// The Body mixin, through fetch_body.zig
// ============================================================================

const body_kind = fetch_body.Owner.Kind{ .of = bodyOwner, .package = packageSteps };

/// This Request as the Body mixin's steps see it.
pub fn bodyOwner(instance: *runtime.Instance) ?fetch_body.Owner {
    const state = instance.stateAs(State) orelse return null;
    const internal = state.own._internal orelse return null;
    const body: ?*fetch.internal.Body = if (internal.request.body) |rb| switch (rb) {
        .body => |b| b,
        // Never a Request object's: its constructor makes a Body.
        .bytes => null,
    } else null;
    return .{
        .instance = instance,
        .stream = &state.own.body,
        .pin = &internal.body_pin,
        .body = body,
        .kind = &body_kind,
    };
}

/// dom.fetch_objects: this Request's body's stream, when the body's bytes
/// are only in it - a body with a null source: a ReadableStream, or a proxy
/// of one. A body of bytes is sent as its bytes, whatever its stream.
fn bodyStreamToSend(request_object: *runtime.Instance) ?*runtime.Instance {
    const o = bodyOwner(request_object) orelse return null;
    const body = o.body orelse return null;
    if (body.source != .none) return null;
    return o.stream.*;
}

/// blob()'s and formData()'s steps on this Request's body's `bytes`.
fn packageSteps(instance: *runtime.Instance, method: fetch_body.Method, bytes: []const u8) anyerror!*runtime.Instance {
    const internal = instance.getState(State).own._internal.?;
    const allocator = internal.allocator;
    const content_type = internal.request.header_list.get(allocator, "content-type") catch null;
    defer if (content_type) |ct| allocator.free(ct);
    switch (method) {
        // blob(): a Blob whose contents are bytes and whose type is this's
        // MIME type (BlobData lowercases it, and drops one it cannot hold).
        .blob => {
            const blob_data = try BlobData.init(allocator, bytes, content_type orelse "");
            errdefer blob_data.deinit();
            return BlobImpl.createFromBlobData(allocator, instance.ctx, blob_data);
        },
        // formData(): the entries this's Content-Type says how to parse
        // bytes into.
        .form_data => {
            const FormDataImpl = @import("FormData.zig");
            const form_data = try fetch_body.parseFormData(allocator, content_type, bytes);
            errdefer form_data.deinit();
            return FormDataImpl.createFromInternal(allocator, instance.ctx, form_data);
        },
        .array_buffer, .bytes, .json, .text => unreachable,
    }
}

fn consumeBody(instance: *runtime.Instance, method: fetch_body.Method) anyerror!runtime.JSValue {
    const o = bodyOwner(instance) orelse return error.InvalidState;
    return fetch_body.consume(o, method);
}

// === Methods - STUBS (Option A) ===

/// clone() - Clones the Request
/// Spec: https://fetch.spec.whatwg.org/#dom-request-clone
pub fn call_clone(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const state = instance.getState(State);
    const internal = state.own._internal.?;

    // Step 1: If this is unusable, throw a TypeError.
    if (fetch_body.isUnusable(bodyOwner(instance).?)) return error.TypeError;

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
    cloned_internal.signal_pin.hold(cloned_state.own.signal);

    // "Clone a request" step 2 - "clone a body": a body already in its
    // stream is teed, this request reading one branch and the clone the
    // other. (The request clone above teed a body still arriving.)
    try fetch_body.cloneStream(bodyOwner(instance).?, bodyOwner(cloned_instance).?);

    return cloned_instance;
}

/// arrayBuffer() - Returns promise fulfilled with body as ArrayBuffer
/// Spec: https://fetch.spec.whatwg.org/#dom-body-arraybuffer
pub fn call_arrayBuffer(instance: *runtime.Instance) anyerror!runtime.JSValue {
    return consumeBody(instance, .array_buffer);
}

/// blob() - Returns promise fulfilled with body as Blob
/// Spec: https://fetch.spec.whatwg.org/#dom-body-blob
pub fn call_blob(instance: *runtime.Instance) anyerror!runtime.JSValue {
    return consumeBody(instance, .blob);
}

/// bytes() - Returns promise fulfilled with body as Uint8Array
/// Spec: https://fetch.spec.whatwg.org/#dom-body-bytes
pub fn call_bytes(instance: *runtime.Instance) anyerror!runtime.JSValue {
    return consumeBody(instance, .bytes);
}

/// formData() - Returns promise fulfilled with body as FormData
/// Spec: https://fetch.spec.whatwg.org/#dom-body-formdata
pub fn call_formData(instance: *runtime.Instance) anyerror!runtime.JSValue {
    return consumeBody(instance, .form_data);
}

/// json() - Returns promise fulfilled with body parsed as JSON
/// Spec: https://fetch.spec.whatwg.org/#dom-body-json
pub fn call_json(instance: *runtime.Instance) anyerror!runtime.JSValue {
    return consumeBody(instance, .json);
}

/// text() - Returns promise fulfilled with body as string
/// Spec: https://fetch.spec.whatwg.org/#dom-body-text
pub fn call_text(instance: *runtime.Instance) anyerror!runtime.JSValue {
    return consumeBody(instance, .text);
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
