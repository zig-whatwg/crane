//! Implementation for Response interface
//!
//! Wraps Fetch internal InternalResponse to provide WebIDL interface.
//! Spec: https://fetch.spec.whatwg.org/#response-class
//!
//! NOTE: This is Option A (minimal but compiling) - constructors/body methods are stubbed.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");

// Import Fetch internal structures
const fetch = @import("fetch");
const InternalResponse = fetch.internal.InternalResponse;

// Import Blob WebIDL wrapper
const BlobImpl = @import("Blob.zig");
const webidl = @import("webidl");

const Response = interfaces.Response;
const same_object = @import("same_object.zig");
const js = @import("streams_js.zig");
const srd = @import("streams_readable.zig");
const BodyPipe = fetch.internal.BodyPipe;
const fetch_body = @import("fetch_body.zig");
const engine = @import("engine");

// Exposed for tests/v8's Deferred lifetime test.
pub const streams_js = @import("streams_js.zig");
const abort_algorithms = @import("dom").abort_algorithms;

pub const State = Response.State;

pub const ImplError = error{
    OutOfMemory,
    TypeError,
    InvalidState,
    RangeError,
};

/// Internal state wraps Fetch InternalResponse
pub const InternalState = struct {
    allocator: std.mem.Allocator,
    response: *InternalResponse,
    /// The guard of this object's Headers: "response" for a Response script
    /// constructs, "immutable" for one fetch() creates.
    headers_guard: fetch.internal.HeaderGuard = .response,
    /// Keeps `this.body`'s stream alive for as long as this object - see
    /// `same_object.zig`. (`headers` works the other way round: the Headers
    /// object keeps its owner alive, because its list lives in the owner.)
    body_pin: same_object.Pin = .{},
    /// The signal of the fetch() call that made this response, which it
    /// follows (`followSignal`), as (address, slab generation), and held
    /// alive for as long as this object: an abort after the response
    /// errors its body, however long after.
    signal: ?*runtime.Instance = null,
    signal_generation: u64 = 0,
    signal_pin: same_object.Pin = .{},

    /// The followed signal, if it is still the one followed.
    fn liveSignal(self: *const InternalState) ?*runtime.Instance {
        const signal = self.signal orelse return null;
        if (runtime.SlabAllocator.generationOf(signal) != self.signal_generation) return null;
        return signal;
    }
};

/// Initialize instance
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    // fetch() hands a Response object its response through this hook.
    @import("dom").fetch_objects.installResponse(.{ .adopt = &adoptResponse, .follow = &followSignal });

    const instance = try runtime.Instance.init(allocator, StateType, vtable, ctx);
    errdefer runtime.Instance.deinit(instance);

    const internal = try allocator.create(InternalState);
    errdefer allocator.destroy(internal);

    const response = try InternalResponse.init(allocator);
    errdefer response.deinit();

    internal.* = .{
        .allocator = allocator,
        .response = response,
    };

    const state = instance.getState(StateType);
    state.own._internal = internal;

    return instance;
}

/// Create a Response from an existing InternalResponse
/// This is used by fetch() to wrap the result in a WebIDL Response
pub fn fromInternalResponse(
    allocator: std.mem.Allocator,
    response: *InternalResponse,
    ctx: runtime.Context,
) !*runtime.Instance {
    const instance = try runtime.Instance.init(allocator, State, &Response.vtable, ctx);
    errdefer runtime.Instance.deinit(instance);

    const internal = try allocator.create(InternalState);
    errdefer allocator.destroy(internal);

    internal.* = .{
        .allocator = allocator,
        .response = response,
    };

    const state = instance.getState(State);
    state.own._internal = internal;

    return instance;
}

/// dom.fetch_objects, Fetch "create a Response object" steps 2-3 for a
/// Response object just made: its response becomes `response`, which it now
/// owns, and its headers' guard `guard`.
fn adoptResponse(response_object: *runtime.Instance, response: *anyopaque, guard: @import("dom").fetch_objects.Guard) void {
    const state = response_object.stateAs(State) orelse return;
    const internal = state.own._internal orelse return;
    internal.response.deinit();
    internal.response = @ptrCast(@alignCast(response));
    internal.headers_guard = switch (guard) {
        .immutable => .immutable,
        .request => .request,
        .request_no_cors => .request_no_cors,
        .response => .response,
        .none => .none,
    };
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
        // No Headers object can be alive here: a live one pins this response,
        // because its list is `response.header_list` below (Headers.zig,
        // InternalState.Owner). At context teardown the order is arbitrary,
        // which is what that object's generation check is for.
        internal.body_pin.release();
        if (internal.liveSignal()) |signal| abort_algorithms.remove(signal, instance);
        internal.signal = null;
        internal.signal_pin.release();

        internal.response.deinit();
        allocator.destroy(internal);
    }
    // NOTE: Do NOT call runtime.Instance.deinit(instance) here!
    // The GC integration layer handles slab freeing after this returns.
}

/// dom.fetch_objects: `response_object` follows `signal`, the signal of the
/// fetch() call that made it.
///
/// Fetch keeps responseObject in the abort steps it adds to the request's
/// signal: once aborted, "abort the fetch() call" step 5 errors the body if
/// it is readable - after the body has arrived too, while nobody has read
/// it. Gecko's FetchBody is an AbortFollower of that signal for the same
/// reason (dom/fetch/Fetch.cpp, FetchBody<Derived>::RunAbortAlgorithm), and
/// its ConsumeBody rejects with the abort reason once the signal is aborted,
/// before the bodyUsed check - which is what `consumeThroughStream` does.
fn followSignal(response_object: *runtime.Instance, signal: *runtime.Instance) void {
    const state = response_object.stateAs(State) orelse return;
    const internal = state.own._internal orelse return;
    if (internal.signal != null) return;
    abort_algorithms.add(signal, .{ .ctx = response_object, .run = signalAborted }) catch return;
    internal.signal = signal;
    internal.signal_generation = runtime.SlabAllocator.generationOf(signal);
    internal.signal_pin.hold(signal);
}

/// The followed signal is aborted: error the body's stream, if it is
/// readable, with the abort reason. A stream made later is errored as it is
/// made (`get_body`).
fn signalAborted(context: *anyopaque) void {
    const instance: *runtime.Instance = @ptrCast(@alignCast(context));
    const state = instance.stateAs(State) orelse return;
    const stream = state.own.body orelse return;
    errorWithAbortReason(instance, stream);
}

/// The followed signal's abort reason, owned, once it is aborted.
fn abortReason(instance: *runtime.Instance, realm: js.Realm) ?js.Value {
    const internal = instance.getState(State).own._internal orelse return null;
    const signal = internal.liveSignal() orelse return null;
    if (!(interfaces.AbortSignal.get_aborted(signal) catch false)) return null;
    const reason = interfaces.AbortSignal.get_reason(signal) catch return null;
    return realm.fromRuntime(reason) catch null;
}

/// Error `stream`, if it is readable, with the followed signal's abort
/// reason - "error response's body with error".
fn errorWithAbortReason(instance: *runtime.Instance, stream: *runtime.Instance) void {
    const slots = srd.streamOf(stream) orelse return;
    if (slots.state != .readable) return;
    const realm = js.Realm.of(instance) catch return;
    const reason = abortReason(instance, realm) orelse return;
    defer js.dispose(reason);
    const controller = slots.controller orelse return;
    if (srd.byteControllerOf(controller) != null) {
        srd.byteControllerError(realm, controller, reason);
    } else {
        srd.defaultControllerError(realm, controller, reason);
    }
}

/// Constructor - Creates a Response with optional body and init
/// Spec: https://fetch.spec.whatwg.org/#dom-response
pub fn call_constructor(ctx: runtime.Context, body: webidl.Opt(?typedefs.BodyInit), init_data: webidl.Opt(dictionaries.ResponseInit)) !*runtime.Instance {
    // 1-2. This's response is a new response, its headers a new Headers
    //      with guard "response" (init, InternalState.headers_guard).
    const instance = try init(ctx.allocator, State, &Response.vtable, ctx);
    errdefer deinit(instance);
    const internal = instance.getState(State).own._internal.?;

    // 3-4. Let bodyWithType be null; if body is non-null, set it to the
    //      result of extracting body.
    var body_with_type: ?fetch_body.Extracted = null;
    defer if (body_with_type) |*b| b.deinit();
    if (body.wasPassed()) if (body.value) |body_init| {
        body_with_type = fetch_body.extract(internal.allocator, body_init, false) catch |err| return switch (err) {
            error.OutOfMemory => error.OutOfMemory,
            error.TypeError => error.TypeError,
        };
    };

    // 5. Perform initialize a response given this, init, and bodyWithType.
    try initializeResponse(instance, if (init_data.wasPassed()) init_data.value else .{}, if (body_with_type) |*b| b else null);
    return instance;
}

/// Fetch "initialize a response" given `instance`, `init`, and null or a
/// body with type, whose body this takes.
fn initializeResponse(instance: *runtime.Instance, init_dict: dictionaries.ResponseInit, body: ?*fetch_body.Extracted) !void {
    const state = instance.getState(State);
    const internal = state.own._internal.?;

    // 1. If init["status"] is not in the range 200 to 599, inclusive, then
    //    throw a RangeError.
    if (init_dict.status) |status| {
        if (status < 200 or status > 599) return error.RangeError;
    }

    // 2. If init["statusText"] is not the empty string and does not match
    //    the reason-phrase token production, then throw a TypeError.
    if (init_dict.statusText) |status_text| {
        if (!isReasonPhrase(status_text)) return error.TypeError;
    }

    // 3. Set response's response's status to init["status"].
    if (init_dict.status) |status| internal.response.status = status;

    // 4. Set response's response's status message to init["statusText"].
    //    The response keeps its OWN copy: this argument belongs to the
    //    WebIDL layer, which frees it when the call returns. (No default
    //    message: statusText defaults to the empty string.)
    if (init_dict.statusText) |status_text| try internal.response.setStatusMessage(status_text);

    // 5. If init["headers"] exists, then fill response's headers with it.
    if (init_dict.headers) |headers_init| {
        switch (headers_init) {
            .sequence_byte_string_sequence => |outer_seq| {
                for (outer_seq) |inner_seq| {
                    if (inner_seq.len >= 2) {
                        try internal.response.header_list.append(inner_seq[0], inner_seq[1]);
                    }
                }
            },
            .byte_string_byte_string_record => |entries| {
                for (entries) |entry| {
                    try internal.response.header_list.append(entry.key, entry.value);
                }
            },
        }
    }

    // 6. If body is non-null, then:
    const b = body orelse return;
    // 6.1. If response's status is a null body status, then throw a
    //      TypeError.
    if (fetch.internal.isNullBodyStatus(internal.response.status)) return error.TypeError;
    // 6.2. Set response's body to body's body.
    internal.response.body = b.takeBody();
    if (b.stream) |stream| {
        // A ReadableStream is the body's stream itself.
        state.own.body = stream;
        internal.body_pin.hold(stream);
    }
    // 6.3. If body's type is non-null and response's header list does not
    //      contain `Content-Type`, then append (`Content-Type`, body's type).
    if (b.content_type) |content_type| {
        if (!internal.response.header_list.contains("Content-Type")) {
            try internal.response.header_list.append("Content-Type", content_type);
        }
    }
}

// === Static Methods ===
// Static methods use call_static_<name> convention

pub fn call_static_error(instance: *runtime.Instance) anyerror!*runtime.Instance {
    // Static method - use context directly, not instance state
    // (instance is just a template for context/allocator access)
    const allocator = instance.ctx.allocator;
    const ctx = instance.ctx;

    const error_instance = try init(allocator, State, &Response.vtable, ctx);
    const error_state = error_instance.getState(State);
    const internal = error_state.own._internal.?;

    internal.response.response_type = .@"error";
    internal.response.status = 0;

    return error_instance;
}

pub fn call_static_redirect(instance: *runtime.Instance, url: runtime.USVString, status: webidl.Opt(u16)) anyerror!*runtime.Instance {
    // Unwrap Opt for status (default to 302 per spec)
    const status_val = if (status.wasPassed()) status.value else 302;
    if (status_val != 301 and status_val != 302 and status_val != 303 and status_val != 307 and status_val != 308) {
        return error.RangeError;
    }

    // Static method - use context directly, not instance state
    const allocator = instance.ctx.allocator;
    const ctx = instance.ctx;

    const redirect_instance = try init(allocator, State, &Response.vtable, ctx);
    const redirect_state = redirect_instance.getState(State);
    const internal = redirect_state.own._internal.?;

    internal.response.status = status_val;
    try internal.response.header_list.append("Location", url);

    return redirect_instance;
}

/// The static `json(data, init)` method.
///
/// Spec: https://fetch.spec.whatwg.org/#dom-response-json
pub fn call_static_json(instance: *runtime.Instance, data: runtime.JSValue, init_data: webidl.Opt(dictionaries.ResponseInit)) anyerror!*runtime.Instance {
    // The current realm: the static method's own (`instance` stands in for
    // it when no script is running).
    const realm = engine.currentRealm() orelse instance.ctx;
    const allocator = realm.allocator;

    // 1. Let bytes be the result of running serialize a JavaScript value to
    //    JSON bytes on data.
    const bytes = try engine.serializeJsonToBytes(realm, data, allocator);
    defer allocator.free(bytes);

    // 2. Let body be the result of extracting bytes: a body of them (a byte
    //    sequence's type is null; step 4 gives this one its type).
    var body: fetch_body.Extracted = .{ .allocator = allocator };
    defer body.deinit();
    body.body = try fetch.internal.Body.fromBytes(allocator, bytes);
    body.content_type = try allocator.dupe(u8, "application/json");

    // 3. Let responseObject be the result of creating a Response object,
    //    given a new response, "response", and the current realm.
    const response_object = try init(allocator, State, &Response.vtable, realm);
    errdefer deinit(response_object);

    // 4. Perform initialize a response given responseObject, init, and
    //    (body, "application/json").
    try initializeResponse(response_object, if (init_data.wasPassed()) init_data.value else .{}, &body);

    // 5. Return responseObject.
    return response_object;
}

// === Property Getters ===

pub fn get_type(instance: *runtime.Instance) anyerror!enums.ResponseType {
    const state = instance.getState(State);
    const internal = state.own._internal.?;

    return switch (internal.response.response_type) {
        .basic => ._basic_,
        .cors => ._cors_,
        .default => ._default_,
        .@"error" => ._error_,
        .@"opaque" => ._opaque_,
        .opaqueredirect => ._opaqueredirect_,
    };
}

/// Spec: https://fetch.spec.whatwg.org/#dom-response-url - the empty string if
/// this's response's URL is null, otherwise its serialization with exclude
/// fragment set.
///
/// OWNERSHIP: a getter returning USVString/ByteString/DOMString has its result
/// FREED by the interface layer (the `needs_cleanup` defer in
/// `engines/v8/interface.zig`). Returning the response's own URL-list entry
/// handed its storage to `allocator.free`, so the second read of `url` - or the
/// response's own `deinit` - freed it again.
pub fn get_url(instance: *runtime.Instance) anyerror!runtime.USVString {
    const state = instance.getState(State);
    const internal = state.own._internal.?;

    // Return last URL in URL list (for redirects)
    if (internal.response.url_list.items.len > 0) {
        const url = internal.response.url_list.items[internal.response.url_list.items.len - 1];
        // TODO: serialize with the exclude fragment flag set.
        if (url.len == 0) return "";
        return try instance.ctx.allocator.dupe(u8, url);
    }

    return "";
}

pub fn get_redirected(instance: *runtime.Instance) anyerror!bool {
    const state = instance.getState(State);
    const internal = state.own._internal.?;
    return internal.response.url_list.items.len > 1;
}

pub fn get_status(instance: *runtime.Instance) anyerror!u16 {
    const state = instance.getState(State);
    const internal = state.own._internal.?;
    return internal.response.status;
}

pub fn get_ok(instance: *runtime.Instance) anyerror!bool {
    const state = instance.getState(State);
    const internal = state.own._internal.?;
    return internal.response.status >= 200 and internal.response.status <= 299;
}

/// Spec: https://fetch.spec.whatwg.org/#dom-response-statustext
///
/// Owned copy - see `get_url`. This one was the loudest: a default status text
/// was a string LITERAL, and freeing it wrote to read-only memory
/// (`Bus error` in `memset`, from `Allocator.free`).
pub fn get_statusText(instance: *runtime.Instance) anyerror!runtime.ByteString {
    const state = instance.getState(State);
    const internal = state.own._internal.?;
    if (internal.response.status_message.len == 0) return "";
    return try instance.ctx.allocator.dupe(u8, internal.response.status_message);
}

pub fn get_headers(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const state = instance.getState(State);
    const internal = state.own._internal.?;

    // Only reached when the generated getter's `cached_headers` is empty - it
    // is the one cache ([SameObject]). A second cache here used to hold the
    // same pointer where nothing could clear it.
    //
    // The Headers object's list IS this response's header list, by reference,
    // so it keeps this response alive and clears `cached_headers` when it is
    // collected - see Headers.InternalState.Owner.
    const Headers = @import("Headers.zig");
    return Headers.initWithHeaderList(
        internal.allocator,
        instance.ctx,
        &internal.response.header_list,
        internal.headers_guard,
        instance,
        &state.own.cached_headers,
    );
}

/// Get body
///
/// Spec: https://fetch.spec.whatwg.org/#dom-body-body - the body's stream,
/// or null for a null body.
///
/// A response fetch() made is handed on at its headers, and its body is
/// still arriving: the stream reads it from the body's pipe as it comes. A
/// body that is bytes becomes a stream of those bytes. Either way the stream
/// takes the bytes over, and from then on the body methods read the stream.
pub fn get_body(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    const o = bodyOwner(instance) orelse return null;
    return fetch_body.bodyStream(o);
}

/// Get bodyUsed
///
/// Spec: "return true if this's body is non-null and this's body's stream
/// is disturbed; otherwise false."
pub fn get_bodyUsed(instance: *runtime.Instance) anyerror!bool {
    const o = bodyOwner(instance) orelse return false;
    return fetch_body.bodyUsed(o);
}

// === Methods - STUBS (Option A) ===

/// clone() - Clones the Response
/// Spec: https://fetch.spec.whatwg.org/#dom-response-clone
pub fn call_clone(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const state = instance.getState(State);
    const internal = state.own._internal.?;

    // Step 1: If this is unusable, throw TypeError
    if (isUnusable(instance)) return error.TypeError;

    // Step 2: Clone the internal response. A body still arriving is teed at
    // its pipe - "clone a body" tees its stream - so the clone reads its own
    // copy of what arrives.
    const cloned_response = try internal.response.clone();
    errdefer cloned_response.deinit();

    // Step 3: Create new Response instance with cloned response
    const cloned_instance = try init(internal.allocator, State, &Response.vtable, instance.ctx);
    errdefer deinit(cloned_instance);

    const cloned_state = cloned_instance.getState(State);
    const cloned_internal = cloned_state.own._internal.?;

    // Replace default response with cloned one
    cloned_internal.response.deinit();
    cloned_internal.response = cloned_response;
    cloned_internal.headers_guard = internal.headers_guard;

    // A body already in its stream: "clone a body" steps 1-3 - tee the
    // stream; this body reads the first branch, the clone the second.
    try fetch_body.cloneStream(bodyOwner(instance).?, bodyOwner(cloned_instance).?);

    return cloned_instance;
}

/// arrayBuffer() - Returns promise fulfilled with body as ArrayBuffer
/// Spec: https://fetch.spec.whatwg.org/#dom-body-arraybuffer
pub fn call_arrayBuffer(instance: *runtime.Instance) anyerror!runtime.JSValue {
    return consumeThroughStream(instance, .array_buffer);
}

/// blob() - Returns promise fulfilled with body as Blob
/// Spec: https://fetch.spec.whatwg.org/#dom-body-blob
pub fn call_blob(instance: *runtime.Instance) anyerror!runtime.JSValue {
    return consumeThroughStream(instance, .blob);
}

/// bytes() - Returns promise fulfilled with body as Uint8Array
/// Spec: https://fetch.spec.whatwg.org/#dom-body-bytes
pub fn call_bytes(instance: *runtime.Instance) anyerror!runtime.JSValue {
    return consumeThroughStream(instance, .bytes);
}

/// formData() - Returns promise fulfilled with body as FormData
/// Spec: https://fetch.spec.whatwg.org/#dom-body-formdata
pub fn call_formData(instance: *runtime.Instance) anyerror!runtime.JSValue {
    return consumeThroughStream(instance, .form_data);
}

/// json() - Returns promise fulfilled with body parsed as JSON
/// This is the instance method from the Body mixin
/// Spec: https://fetch.spec.whatwg.org/#dom-body-json
pub fn call_json(instance: *runtime.Instance) anyerror!runtime.JSValue {
    return consumeThroughStream(instance, .json);
}

/// text() - Returns promise fulfilled with body as string
/// Spec: https://fetch.spec.whatwg.org/#dom-body-text
pub fn call_text(instance: *runtime.Instance) anyerror!runtime.JSValue {
    return consumeThroughStream(instance, .text);
}

// ============================================================================
// The Body mixin, through fetch_body.zig
// ============================================================================

const body_kind = fetch_body.Owner.Kind{
    .of = bodyOwner,
    .package = packageSteps,
    .rejection = abortReason,
    .made = errorWithAbortReason,
};

/// This Response as the Body mixin's steps see it.
fn bodyOwner(instance: *runtime.Instance) ?fetch_body.Owner {
    const state = instance.stateAs(State) orelse return null;
    const internal = state.own._internal orelse return null;
    return .{
        .instance = instance,
        .stream = &state.own.body,
        .pin = &internal.body_pin,
        .body = internal.response.body,
        .kind = &body_kind,
    };
}

/// blob()'s and formData()'s steps on this Response's body's `bytes`.
fn packageSteps(instance: *runtime.Instance, method: fetch_body.Method, bytes: []const u8) anyerror!*runtime.Instance {
    const internal = instance.getState(State).own._internal.?;
    const allocator = internal.allocator;
    const content_type = internal.response.header_list.get(allocator, "content-type") catch null;
    defer if (content_type) |ct| allocator.free(ct);
    switch (method) {
        // blob(): a Blob whose contents are bytes and whose type is this's
        // MIME type (BlobData lowercases it, and drops one it cannot hold).
        .blob => {
            const blob_data = try @import("file").BlobData.init(allocator, bytes, content_type orelse "");
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

fn consumeThroughStream(instance: *runtime.Instance, method: fetch_body.Method) anyerror!runtime.JSValue {
    const o = bodyOwner(instance) orelse return error.InvalidState;
    return fetch_body.consume(o, method);
}

fn isUnusable(instance: *runtime.Instance) bool {
    const o = bodyOwner(instance) orelse return false;
    return fetch_body.isUnusable(o);
}

// === Helper Functions ===

/// Does `bytes` match RFC 9112's `reason-phrase` production?
///
///     reason-phrase = 1*( HTAB / SP / VCHAR / obs-text )
///
/// The caller has already let the empty string through, which "initialize a
/// response" step 2 exempts explicitly.
fn isReasonPhrase(bytes: []const u8) bool {
    for (bytes) |c| {
        const ok = c == '\t' or c == ' ' or (c >= 0x21 and c <= 0x7E) or c >= 0x80;
        if (!ok) return false;
    }
    return true;
}

// === Internal Helper Functions (for Cache API) ===

/// Response data for cache storage
pub const ResponseData = struct {
    status: u16,
    status_text: []const u8,
    body: ?[]const u8,
};

/// Get response data for cache storage
pub fn getResponseData(instance: *runtime.Instance) ResponseData {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return .{
        .status = 200,
        .status_text = "OK",
        .body = null,
    };

    return .{
        .status = internal.response.status,
        .status_text = internal.response.status_message,
        .body = if (internal.response.body) |body| body.getBytes() else null,
    };
}
