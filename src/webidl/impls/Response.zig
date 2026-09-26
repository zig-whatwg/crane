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
const v8 = @import("v8");
const BodyPipe = fetch.internal.BodyPipe;

pub const State = Response.State;

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
};

/// Initialize instance
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    // fetch() hands a Response object its response through this hook.
    @import("dom").fetch_objects.installResponse(.{ .adopt = &adoptResponse });

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

        internal.response.deinit();
        allocator.destroy(internal);
    }
    // NOTE: Do NOT call runtime.Instance.deinit(instance) here!
    // The GC integration layer handles slab freeing after this returns.
}

/// Constructor - Creates a Response with optional body and init
/// Spec: https://fetch.spec.whatwg.org/#dom-response
pub fn call_constructor(ctx: runtime.Context, body: webidl.Opt(?typedefs.BodyInit), init_data: webidl.Opt(dictionaries.ResponseInit)) !*runtime.Instance {
    const instance = try init(ctx.allocator, State, &Response.vtable, ctx);
    errdefer deinit(instance);

    const state = instance.getState(State);
    const internal = state.own._internal.?;

    // "Initialize a response" - https://fetch.spec.whatwg.org/#initialize-a-response
    if (init_data.wasPassed()) {
        // Step 1: If init["status"] is not in the range 200 to 599, inclusive,
        // then throw a RangeError.
        if (init_data.value.status) |status| {
            if (status < 200 or status > 599) {
                return error.RangeError;
            }
        }

        // Step 2: If init["statusText"] is not the empty string and does not
        // match the reason-phrase token production, then throw a TypeError.
        if (init_data.value.statusText) |status_text| {
            if (!isReasonPhrase(status_text)) return error.TypeError;
        }

        // Step 3: Set response's response's status to init["status"].
        if (init_data.value.status) |status| {
            internal.response.status = status;
        }

        // Step 4: Set response's response's status message to
        // init["statusText"]. The response keeps its OWN copy: this argument
        // belongs to the WebIDL layer, which frees it when the constructor
        // returns.
        if (init_data.value.statusText) |status_text| {
            try internal.response.setStatusMessage(status_text);
        }

        // Handle headers from init
        if (init_data.value.headers) |headers_init| {
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
    }

    // No default status message: ResponseInit's `statusText` defaults to the
    // empty string, and `new Response().statusText` is "" in every engine.
    // Inventing "OK" from the status code was a deviation, and it pointed the
    // field at a string literal that the binding layer then tried to free.

    // Handle body parameter
    if (body.wasPassed()) {
        if (body.value) |body_init| {
            // Per Fetch spec: If init["status"] is a null body status, then throw a TypeError
            // Null body statuses are: 204, 205, 304
            const status = internal.response.status;
            if (status == 204 or status == 205 or status == 304) {
                return error.TypeError;
            }

            // Extract body bytes based on BodyInit variant
            // BodyInit = (ReadableStream or XMLHttpRequestBodyInit)
            // XMLHttpRequestBodyInit = (Blob or BufferSource or FormData or URLSearchParams or USVString)
            const body_bytes: ?[]const u8 = switch (body_init) {
                .readable_stream => null, // ReadableStream not yet supported for body extraction
                .xmlhttp_request_body_init => |xhr_body| switch (xhr_body) {
                    .usvstring => |s| s,
                    .blob, .form_data, .urlsearch_params => null, // Not yet supported
                    .buffer_source => null, // BufferSource not yet fully implemented
                },
            };

            const is_string = if (body_init == .xmlhttp_request_body_init)
                body_init.xmlhttp_request_body_init == .usvstring
            else
                false;

            if (body_bytes) |bytes| {
                if (bytes.len > 0) {
                    // Create Body from bytes
                    const fetch_body = fetch.internal.Body.fromBytes(ctx.allocator, bytes) catch {
                        return error.OutOfMemory;
                    };
                    internal.response.body = fetch_body;

                    // Set Content-Type header if not already set and body is string
                    if (is_string) {
                        // Per spec: if body is USVString, set Content-Type to text/plain;charset=UTF-8
                        const has_content_type = internal.response.header_list.contains("content-type");
                        if (!has_content_type) {
                            internal.response.header_list.append("Content-Type", "text/plain;charset=UTF-8") catch {};
                        }
                    }
                }
            }
        }
    }

    return instance;
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

/// Response.json(data, init) - static method
/// Creates a Response from JSON-serialized data
/// Named call_json_static to avoid collision with instance method call_json
///
/// Note: Takes instance as first param to match V8 static method calling convention.
/// The instance is a template instance that provides allocator/context.
pub fn call_static_json(instance: *runtime.Instance, data: runtime.JSValue, init_data: webidl.Opt(dictionaries.ResponseInit)) anyerror!*runtime.Instance {
    const ctx = instance.ctx;

    // Step 1: Let bytes be the result of running serialize a JavaScript value to JSON bytes on data
    // For now, convert JSValue to string representation
    const body_bytes: []const u8 = switch (data) {
        .string => |s| s.data,
        .boolean => |b| if (b) "true" else "false",
        .null => "null",
        .undefined => "undefined",
        .number => "0", // TODO: proper number serialization
        else => "{}",
    };

    // Create a body from the JSON bytes
    const body = typedefs.BodyInit{ .xmlhttp_request_body_init = .{ .usvstring = body_bytes } };
    const body_opt = webidl.Opt(?typedefs.BodyInit).passed(body);
    const json_instance = try call_constructor(ctx, body_opt, init_data);
    const json_state = json_instance.getState(State);
    const internal = json_state.own._internal.?;

    try internal.response.header_list.set("Content-Type", "application/json;charset=utf-8");

    return json_instance;
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
    const state = instance.getState(State);
    const internal = state.own._internal.?;

    // If we already have a cached ReadableStream, return it
    if (state.own.body) |cached_body| {
        return cached_body;
    }

    const body = internal.response.body orelse return null;
    const pipe = if (body.pipe) |p| p else blk: {
        // A body with no bytes and no source is null (a Response made with
        // no body leaves it that way).
        if (body.data.items.len == 0 and body.source == .none) return null;
        // Bytes: the stream of them is a pipe that has already ended.
        const source = try fetch.internal.PipeSource.create(internal.allocator);
        const p = source.branch() catch |err| {
            source.finish();
            return err;
        };
        source.push(body.data.items);
        source.finish();
        break :blk p;
    };
    body.pipe = null;

    const stream_instance = try PipeStream.create(instance.ctx, pipe);

    // Cache the stream for future calls
    // Note: This modifies state, which is mutable through the instance
    @constCast(&state.own).body = stream_instance;
    // `state.own.body` is a pointer V8 cannot see: hold the stream's wrapper
    // for as long as this object, or a collection frees the stream under it.
    internal.body_pin.hold(stream_instance);

    return stream_instance;
}

/// Get bodyUsed
///
/// Spec: "return true if this's body is non-null and this's body's stream
/// is disturbed; otherwise false."
pub fn get_bodyUsed(instance: *runtime.Instance) anyerror!bool {
    const state = instance.getState(State);
    const internal = state.own._internal.?;

    if (state.own.body) |stream| {
        const slots = srd.streamOf(stream) orelse return false;
        return slots.disturbed;
    }
    // Check internal body state
    if (internal.response.body) |body_obj| {
        return body_obj.isUsed();
    }
    return false;
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
    if (state.own.body) |stream| {
        const realm = try js.Realm.of(instance);
        const branches = try srd.tee(realm, stream);
        internal.body_pin.release();
        @constCast(&state.own).body = branches[0];
        internal.body_pin.hold(branches[0]);
        @constCast(&cloned_state.own).body = branches[1];
        cloned_internal.body_pin.hold(branches[1]);
    }

    return cloned_instance;
}

/// arrayBuffer() - Returns promise fulfilled with body as ArrayBuffer
/// Spec: https://fetch.spec.whatwg.org/#dom-body-arraybuffer
///
/// Uses the engine abstraction layer for Promise and ArrayBuffer creation.
pub fn call_arrayBuffer(instance: *runtime.Instance) anyerror!runtime.JSValue {
    if (readsThroughStream(instance)) return consumeThroughStream(instance, .array_buffer);
    return arrayBufferFromBytes(instance);
}

/// `arrayBuffer()` over a body that is its bytes.
fn arrayBufferFromBytes(instance: *runtime.Instance) anyerror!runtime.JSValue {
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

    // Check for disturbed body
    if (internal.response.body) |body| {
        if (body.isDisturbed()) {
            engine.rejectPromise(engine_ctx, promise_handle, error.TypeError) catch {};
            return getPromiseAndCleanup(engine, promise_handle, internal.allocator);
        }
    }

    // Get body bytes
    const body_bytes: []const u8 = if (internal.response.body) |body| blk: {
        const bytes = body.readAllBytes() catch |err| {
            engine.rejectPromise(engine_ctx, promise_handle, err) catch {};
            return getPromiseAndCleanup(engine, promise_handle, internal.allocator);
        };
        break :blk bytes;
    } else "";

    // Create JS ArrayBuffer through engine abstraction
    const createArrayBuffer = engine.createArrayBuffer orelse {
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

    return getPromiseAndCleanup(engine, promise_handle, internal.allocator);
}

/// blob() - Returns promise fulfilled with body as Blob
/// Spec: https://fetch.spec.whatwg.org/#dom-body-blob
///
/// Uses the engine abstraction layer for Promise creation and instance wrapping.
pub fn call_blob(instance: *runtime.Instance) anyerror!runtime.JSValue {
    if (readsThroughStream(instance)) return consumeThroughStream(instance, .blob);
    return blobFromBytes(instance);
}

/// `blob()` over a body that is its bytes.
fn blobFromBytes(instance: *runtime.Instance) anyerror!runtime.JSValue {
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

    const file_mod = @import("file");
    const BlobData = file_mod.BlobData;

    // Get MIME type from Content-Type header
    const mime_type = blk: {
        const ct = internal.response.header_list.get(internal.allocator, "content-type") catch null;
        break :blk ct orelse "";
    };

    // Check for disturbed body
    if (internal.response.body) |body| {
        if (body.isDisturbed()) {
            engine.rejectPromise(engine_ctx, promise_handle, error.TypeError) catch {};
            return getPromiseAndCleanup(engine, promise_handle, internal.allocator);
        }
    }

    // Get body bytes
    const body_bytes: []const u8 = if (internal.response.body) |body| blk: {
        const bytes = body.readAllBytes() catch |err| {
            engine.rejectPromise(engine_ctx, promise_handle, err) catch {};
            return getPromiseAndCleanup(engine, promise_handle, internal.allocator);
        };
        break :blk bytes;
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

    return getPromiseAndCleanup(engine, promise_handle, internal.allocator);
}

/// bytes() - Returns promise fulfilled with body as Uint8Array
/// Spec: https://fetch.spec.whatwg.org/#dom-body-bytes
///
/// Uses the engine abstraction layer for Promise and Uint8Array creation.
pub fn call_bytes(instance: *runtime.Instance) anyerror!runtime.JSValue {
    if (readsThroughStream(instance)) return consumeThroughStream(instance, .bytes);
    return bytesFromBytes(instance);
}

/// `bytes()` over a body that is its bytes.
fn bytesFromBytes(instance: *runtime.Instance) anyerror!runtime.JSValue {
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

    // Check for disturbed body
    if (internal.response.body) |body| {
        if (body.isDisturbed()) {
            engine.rejectPromise(engine_ctx, promise_handle, error.TypeError) catch {};
            return getPromiseAndCleanup(engine, promise_handle, internal.allocator);
        }
    }

    // Get body bytes
    const body_bytes: []const u8 = if (internal.response.body) |body| blk: {
        const bytes = body.readAllBytes() catch |err| {
            engine.rejectPromise(engine_ctx, promise_handle, err) catch {};
            return getPromiseAndCleanup(engine, promise_handle, internal.allocator);
        };
        break :blk bytes;
    } else "";

    // Create JS Uint8Array through engine abstraction
    const createUint8Array = engine.createUint8Array orelse {
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

    return getPromiseAndCleanup(engine, promise_handle, internal.allocator);
}

/// formData() - Returns promise fulfilled with body as FormData
/// Spec: https://fetch.spec.whatwg.org/#dom-body-formdata
///
/// Uses the engine abstraction layer for Promise creation and instance wrapping.
pub fn call_formData(instance: *runtime.Instance) anyerror!runtime.JSValue {
    if (readsThroughStream(instance)) return consumeThroughStream(instance, .form_data);
    return formDataFromBytes(instance);
}

/// `formData()` over a body that is its bytes.
fn formDataFromBytes(instance: *runtime.Instance) anyerror!runtime.JSValue {
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

    // Helper to reject and return (uses module-level getPromiseAndCleanup)
    const rejectAndReturn = struct {
        fn call(eng: anytype, eng_ctx: anytype, handle: anytype, err: anyerror, alloc: std.mem.Allocator) runtime.JSValue {
            eng.rejectPromise(eng_ctx, handle, err) catch {};
            return getPromiseAndCleanup(eng, handle, alloc);
        }
    }.call;

    // Get Content-Type header
    const content_type = internal.response.header_list.get(internal.allocator, "content-type") catch null;
    defer if (content_type) |ct| internal.allocator.free(ct);

    // Check for disturbed body
    if (internal.response.body) |body| {
        if (body.isDisturbed()) {
            return rejectAndReturn(engine, engine_ctx, promise_handle, error.TypeError, internal.allocator);
        }
    }

    // Get body bytes
    const body_bytes: []const u8 = if (internal.response.body) |body| blk: {
        const bytes = body.readAllBytes() catch {
            return rejectAndReturn(engine, engine_ctx, promise_handle, error.TypeError, internal.allocator);
        };
        break :blk bytes;
    } else "";

    // Parse body into FormData based on Content-Type
    const form_data: *xhr.form_data.FormData = if (body_bytes.len > 0) parse_blk: {
        if (content_type) |ct| {
            if (std.mem.indexOf(u8, ct, "multipart/form-data") != null) {
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
                return rejectAndReturn(engine, engine_ctx, promise_handle, error.TypeError, internal.allocator);
            }
        } else {
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

    return getPromiseAndCleanup(engine, promise_handle, internal.allocator);
}

/// json() - Returns promise fulfilled with body parsed as JSON
/// This is the instance method from the Body mixin
/// Spec: https://fetch.spec.whatwg.org/#dom-body-json
///
/// Uses the engine abstraction layer for Promise and JSON parsing.
pub fn call_json(instance: *runtime.Instance) anyerror!runtime.JSValue {
    if (readsThroughStream(instance)) return consumeThroughStream(instance, .json);
    return jsonFromBytes(instance);
}

/// `json()` over a body that is its bytes.
fn jsonFromBytes(instance: *runtime.Instance) anyerror!runtime.JSValue {
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

    // Check for disturbed body
    if (internal.response.body) |body| {
        if (body.isDisturbed()) {
            engine.rejectPromise(engine_ctx, promise_handle, error.TypeError) catch {};
            return getPromiseAndCleanup(engine, promise_handle, internal.allocator);
        }
    }

    // Get body bytes
    const body_bytes: []const u8 = if (internal.response.body) |body| blk: {
        const bytes = body.readAllBytes() catch |err| {
            engine.rejectPromise(engine_ctx, promise_handle, err) catch {};
            return getPromiseAndCleanup(engine, promise_handle, internal.allocator);
        };
        break :blk bytes;
    } else {
        // Null body - reject with SyntaxError (empty JSON is invalid)
        engine.rejectPromise(engine_ctx, promise_handle, error.SyntaxError) catch {};
        return getPromiseAndCleanup(engine, promise_handle, internal.allocator);
    };

    // Parse JSON through engine abstraction
    const parseJson = engine.parseJson orelse {
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

    return getPromiseAndCleanup(engine, promise_handle, internal.allocator);
}

/// text() - Returns promise fulfilled with body as string
/// Spec: https://fetch.spec.whatwg.org/#dom-body-text
///
/// Uses the engine abstraction layer for Promise creation and string creation.
pub fn call_text(instance: *runtime.Instance) anyerror!runtime.JSValue {
    if (readsThroughStream(instance)) return consumeThroughStream(instance, .text);
    return textFromBytes(instance);
}

/// `text()` over a body that is its bytes.
fn textFromBytes(instance: *runtime.Instance) anyerror!runtime.JSValue {
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
    if (internal.response.body) |body| {
        if (body.isDisturbed()) {
            // Reject with TypeError per spec
            engine.rejectPromise(engine_ctx, promise_handle, error.TypeError) catch {};
            return getPromiseAndCleanup(engine, promise_handle, internal.allocator);
        }
    }

    // Get body text
    const body_text: []const u8 = if (internal.response.body) |body| blk: {
        const bytes = body.readAllBytes() catch |err| {
            // Reject on read error
            engine.rejectPromise(engine_ctx, promise_handle, err) catch {};
            return getPromiseAndCleanup(engine, promise_handle, internal.allocator);
        };
        break :blk bytes;
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
        // Clean up even on error
        if (engine.destroyPromiseHandle) |destroy| {
            destroy(promise_handle, internal.allocator);
        }
        return error.InvalidState;
    };

    // Return the JS Promise object wrapped in Promise(T) type
    return getPromiseAndCleanup(engine, promise_handle, internal.allocator);
}

// ============================================================================
// A body read through its stream
// ============================================================================

/// Whether the body methods read this response's body through its stream:
/// once the stream exists - script touched `body` - and for a body still
/// arriving, whose bytes are not all here.
fn readsThroughStream(instance: *runtime.Instance) bool {
    const state = instance.getState(State);
    if (state.own.body != null) return true;
    const internal = state.own._internal orelse return false;
    const body = internal.response.body orelse return false;
    return body.pipe != null;
}

/// "Unusable": the body is disturbed or locked.
fn isUnusable(instance: *runtime.Instance) bool {
    const state = instance.getState(State);
    if (state.own.body) |stream| {
        const slots = srd.streamOf(stream) orelse return false;
        return slots.disturbed or srd.isLocked(slots);
    }
    const internal = state.own._internal orelse return false;
    const body = internal.response.body orelse return false;
    return body.isDisturbed();
}

const BodyMethod = enum { array_buffer, blob, bytes, form_data, json, text };

/// Fetch "consume body", for a body read through its stream: step 1's
/// unusable check, then "fully read body" - a reader takes every chunk - and
/// the method's own steps on the bytes (`settleWithBytes`).
fn consumeThroughStream(instance: *runtime.Instance, method: BodyMethod) anyerror!runtime.JSValue {
    const realm = try js.Realm.of(instance);
    const deferred = try js.Deferred.init(realm);
    var deferred_taken = false;
    errdefer if (!deferred_taken) deferred.deinit();

    // Step 1: If object is unusable, return a promise rejected with a
    // TypeError.
    if (isUnusable(instance)) {
        const e = try realm.typeError("Body is unusable: it has been read or is locked");
        defer js.dispose(e);
        deferred.reject(realm, e);
        return finishReturn(deferred);
    }

    const stream = (try get_body(instance)) orelse {
        // A null body reads as no bytes.
        try settleWithBytes(instance, method, &.{}, realm, deferred);
        return finishReturn(deferred);
    };
    const reader = try srd.acquireDefaultReader(realm, stream);
    // The read holds it through a Zig pointer; wrapping registers it with the
    // wrapper cache, which keeps streams-graph objects for the realm and
    // frees them with it - as ReadableStreamTee and pipeTo do. Unwrapped,
    // nothing ever freed it.
    _ = try realm.wrap(reader);

    const read = try instance.ctx.allocator.create(FullRead);
    deferred_taken = true;
    read.* = .{
        .allocator = instance.ctx.allocator,
        .instance = instance,
        .method = method,
        .realm = realm,
        .deferred = deferred,
        .reader = reader,
    };
    // The Response is what the method's own steps read - its headers, for a
    // blob's type - so it lives until they have run.
    read.keep.hold(instance);
    // Taken first: a stream already closed settles, and frees, the read
    // before readNext returns.
    const promise = js.clone(deferred.promise) catch |err| {
        read.destroy();
        return err;
    };
    read.readNext();
    return js.toReturnOwned(promise);
}

fn finishReturn(deferred: js.Deferred) runtime.JSValue {
    const result = deferred.returnOwned();
    v8.ffi.v8_PromiseResolver_Dispose(deferred.resolver);
    return result;
}

/// The method's own steps - what it does to a body that is its bytes - on
/// `bytes`, the whole of a body read through its stream, settling
/// `deferred` with their outcome.
fn settleWithBytes(instance: *runtime.Instance, method: BodyMethod, bytes: []const u8, realm: js.Realm, deferred: js.Deferred) !void {
    const internal = instance.getState(State).own._internal.?;
    if (internal.response.body == null) {
        internal.response.body = try fetch.internal.Body.fromBytes(internal.allocator, "");
    }
    const body = internal.response.body.?;
    // As a body of these bytes that nobody has read yet: the stream was the
    // one disturbed, and the bytes form does its own marking.
    body.data.clearRetainingCapacity();
    try body.data.appendSlice(body.allocator, bytes);
    body.used = false;
    body.disturbed = false;

    const result = switch (method) {
        .array_buffer => arrayBufferFromBytes(instance),
        .blob => blobFromBytes(instance),
        .bytes => bytesFromBytes(instance),
        .form_data => formDataFromBytes(instance),
        .json => jsonFromBytes(instance),
        .text => textFromBytes(instance),
    } catch |err| {
        const e = try realm.typeError(@errorName(err));
        defer js.dispose(e);
        deferred.reject(realm, e);
        return;
    };
    // The bytes form returns its promise; ours takes on its outcome.
    switch (result) {
        .handle => |h| {
            const promise: js.Value = @ptrCast(@alignCast(h.ptr));
            deferred.resolve(realm, promise);
            if (h.needs_disposal) js.dispose(promise);
        },
        else => deferred.resolveUndefined(realm),
    }
}

/// Fetch "fully read body" through the body's stream: read every chunk,
/// then run the method's steps. Streams "read-loop": each chunk step reads
/// again - from a microtask, so a queue of many chunks is not a deep stack.
const FullRead = struct {
    allocator: std.mem.Allocator,
    instance: *runtime.Instance,
    method: BodyMethod,
    realm: js.Realm,
    deferred: js.Deferred,
    reader: *runtime.Instance,
    bytes: std.ArrayListUnmanaged(u8) = .empty,
    keep: same_object.Pin = .{},

    const vtable = srd.ReadRequest.VTable{ .chunk = chunk, .close = close, .err = fail, .drop = drop };

    fn readNext(self: *FullRead) void {
        const reader = srd.readerOf(self.reader) orelse return self.finishWithTypeError("the body's reader is gone");
        srd.defaultReaderRead(self.realm, reader, .{ .ctx = self, .vtable = &vtable });
    }

    fn chunk(ctx: *anyopaque, realm: js.Realm, value: js.Value) void {
        const self: *FullRead = @ptrCast(@alignCast(ctx));
        _ = realm;
        // "If chunk is not a Uint8Array object, reject with a TypeError."
        const info = js.describeView(value) orelse return self.finishWithTypeError("a body chunk is not a Uint8Array");
        if (info.kind != .uint8) return self.finishWithTypeError("a body chunk is not a Uint8Array");
        const buffer = js.viewBuffer(value) catch return self.finishWithTypeError("a body chunk has no buffer");
        defer js.dispose(buffer);
        const all = js.bufferBytes(buffer) orelse return self.finishWithTypeError("a body chunk's buffer is detached");
        self.bytes.appendSlice(self.allocator, all[info.byte_offset..][0..info.byte_length]) catch return self.finishWithTypeError("out of memory");
        js.queueMicrotask(self.realm, FullRead, self, readNext);
    }

    fn close(ctx: *anyopaque, realm: js.Realm) void {
        const self: *FullRead = @ptrCast(@alignCast(ctx));
        settleWithBytes(self.instance, self.method, self.bytes.items, realm, self.deferred) catch {};
        self.destroy();
    }

    fn fail(ctx: *anyopaque, realm: js.Realm, e: js.Value) void {
        const self: *FullRead = @ptrCast(@alignCast(ctx));
        self.deferred.reject(realm, e);
        self.destroy();
    }

    fn drop(ctx: *anyopaque) void {
        const self: *FullRead = @ptrCast(@alignCast(ctx));
        self.destroy();
    }

    fn finishWithTypeError(self: *FullRead, message: []const u8) void {
        const e = self.realm.typeError(message) catch return self.destroy();
        defer js.dispose(e);
        self.deferred.reject(self.realm, e);
        self.destroy();
    }

    fn destroy(self: *FullRead) void {
        self.keep.release();
        self.deferred.deinit();
        self.bytes.deinit(self.allocator);
        self.allocator.destroy(self);
    }
};

/// The underlying source of a Response's body stream: the body's pipe.
///
/// Fetch's HTTP-network fetch sets the stream up with byte reading support
/// and enqueues bytes as they arrive; here the bytes wait in the pipe until a
/// read asks for them (pull), so what nobody has read stays where a clone can
/// still tee it. The network's news - bytes, the end, a failure - comes as a
/// notification from the event loop's network step, and is acted on in a
/// task in the stream's realm: a pending read gets the bytes, the end closes
/// the stream, a failure errors it at once, read or not.
const PipeStream = struct {
    allocator: std.mem.Allocator,
    ctx: runtime.Context,
    isolate: *v8.ffi.Isolate,
    /// The body's pipe, this source's from creation until cancel or
    /// deinit.
    pipe: ?*BodyPipe,
    /// The stream's controller, from start until deinit.
    controller: ?*runtime.Instance = null,
    /// The promise a pull is waiting on, while the pipe has nothing.
    pending_pull: ?js.Deferred = null,
    /// A task is queued to act on the pipe; it owns this until it runs.
    task_queued: bool = false,
    /// The stream is done with this source (its algorithms were cleared).
    detached: bool = false,
    /// Calls into the stream under way from here: freeing waits for them.
    busy: u32 = 0,

    const vtable = srd.Source.VTable{ .start = start, .pull = pull, .cancel = cancel, .deinit = deinitSource };

    /// CreateReadableByteStream over `pipe`, whose ownership passes in -
    /// on failure too.
    fn create(ctx: runtime.Context, pipe: *BodyPipe) !*runtime.Instance {
        const realm = js.Realm.ofContext(ctx) catch |err| {
            pipe.release();
            return err;
        };
        const self = ctx.allocator.create(PipeStream) catch |err| {
            pipe.release();
            return err;
        };
        self.* = .{ .allocator = ctx.allocator, .ctx = ctx, .isolate = realm.isolate, .pipe = pipe };
        pipe.consumer = .{ .context = self, .notify = notify };
        // Held while the stream is set up: a failed setup clears the
        // source's algorithms, which must not free it under this call.
        self.busy += 1;
        const stream = srd.createReadableByteStream(realm, ctx, .{ .ctx = self, .vtable = &vtable });
        self.busy -= 1;
        if (stream) |s| return s else |err| {
            self.detached = true;
            self.releasePipe();
            self.freeIfDone();
            return err;
        }
    }

    fn start(ctx: ?*anyopaque, realm: js.Realm, controller: *runtime.Instance) js.Error!js.Completion {
        const self: *PipeStream = @ptrCast(@alignCast(ctx.?));
        self.controller = controller;
        return .{ .normal = try realm.undefinedValue() };
    }

    fn pull(ctx: ?*anyopaque, realm: js.Realm, controller: *runtime.Instance) js.Error!js.Value {
        const self: *PipeStream = @ptrCast(@alignCast(ctx.?));
        self.controller = controller;
        self.busy += 1;
        const acted = self.deliver(realm);
        self.busy -= 1;
        if (acted or self.detached) {
            self.freeIfDone();
            return realm.promiseResolvedWithUndefined();
        }
        // Nothing yet: the pull waits for the network.
        const d = try js.Deferred.init(realm);
        self.pending_pull = d;
        return js.clone(d.promise);
    }

    /// Act on what the pipe has: enqueue its bytes, close at its end, error
    /// on its failure. Returns whether there was anything to act on.
    fn deliver(self: *PipeStream, realm: js.Realm) bool {
        const pipe = self.pipe orelse return false;
        const controller = self.controller orelse return false;
        if (pipe.state == .errored) {
            self.errorStream(realm, controller, pipe);
            return true;
        }
        if (pipe.hasBytes()) {
            const bytes = pipe.take() catch return false;
            defer self.allocator.free(bytes);
            self.enqueue(realm, controller, bytes);
            if (self.detached) return true;
            if (pipe.state == .closed) srd.byteControllerClose(realm, controller) catch {};
            return true;
        }
        if (pipe.state == .closed) {
            srd.byteControllerClose(realm, controller) catch {};
            return true;
        }
        return false;
    }

    fn enqueue(self: *PipeStream, realm: js.Realm, controller: *runtime.Instance, bytes: []const u8) void {
        _ = self;
        const buffer = js.allocateBuffer(bytes.len) orelse return;
        defer js.dispose(buffer);
        if (js.bufferBytes(buffer)) |dest| @memcpy(dest[0..bytes.len], bytes);
        const view = js.newView(.uint8, buffer, 0, bytes.len) catch return;
        defer js.dispose(view);
        srd.byteControllerEnqueue(realm, controller, view) catch {};
    }

    /// Error the stream with the pipe's failure: an abort's reason, or a
    /// TypeError for a network error.
    fn errorStream(self: *PipeStream, realm: js.Realm, controller: *runtime.Instance, pipe: *BodyPipe) void {
        _ = self;
        const failure = pipe.failure();
        if (failure.kind == .aborted) {
            if (failure.reason) |reason| {
                // Our own handle to it: erroring the controller clears the
                // stream's algorithms, which lets this source's pipe go -
                // and with the last reader, the source and the reason it
                // holds - before the error reaches the stream.
                const e = js.clone(@ptrCast(@alignCast(reason))) catch return;
                defer js.dispose(e);
                srd.byteControllerError(realm, controller, e);
                return;
            }
            const e = v8.conversions.newDOMExceptionFromContext(realm.isolate, realm.context, "AbortError", "The operation was aborted.") orelse return;
            defer js.dispose(e);
            srd.byteControllerError(realm, controller, e);
            return;
        }
        const e = realm.typeError("network error") catch return;
        defer js.dispose(e);
        srd.byteControllerError(realm, controller, e);
    }

    /// The pipe has news. Called from the event loop's network step, outside
    /// the realm: act on it in a task there.
    fn notify(context: *anyopaque) void {
        const self: *PipeStream = @ptrCast(@alignCast(context));
        if (self.task_queued or self.detached) return;
        if (self.ctx.getOptionalEventLoop()) |loop| {
            self.task_queued = true;
            loop.queueTask(.{ .callback = runTask, .context = self, .drop = dropTask });
            return;
        }
        if (self.ctx.getOptionalTimer()) |timer| {
            if (timer.setTimeout(0, runTask, self) != 0) {
                self.task_queued = true;
                return;
            }
        }
    }

    fn runTask(context: ?*anyopaque) void {
        const self: *PipeStream = @ptrCast(@alignCast(context.?));
        self.task_queued = false;
        if (self.detached or self.ctx.engine_ctx == null) return self.freeIfDone();
        // A task from the event loop, not from script: enter the realm.
        const isolate = self.isolate;
        const entered = v8.ffi.v8_Isolate_GetCurrent() != isolate;
        if (entered) v8.ffi.v8_Isolate_Enter(isolate);
        defer if (entered) v8.ffi.v8_Isolate_Exit(isolate);
        {
            const scope = v8.JsScope.init(self.ctx) orelse return self.freeIfDone();
            defer scope.deinit();
            const realm = js.Realm.ofContext(self.ctx) catch return self.freeIfDone();
            self.busy += 1;
            defer self.busy -= 1;
            const pipe = self.pipe orelse return;
            const controller = self.controller orelse return;
            if (pipe.state == .errored) {
                // Errored at once, read or not: an aborted body's stream
                // errors with the abort reason even while nobody reads.
                self.errorStream(realm, controller, pipe);
            } else if (self.pending_pull != null) {
                if (self.deliver(realm)) {
                    if (self.pending_pull) |d| {
                        self.pending_pull = null;
                        d.resolveUndefined(realm);
                        d.deinit();
                    }
                }
            }
        }
        self.freeIfDone();
        @import("html").worker_v8_context.finishTaskIn(isolate);
    }

    fn dropTask(context: ?*anyopaque) void {
        const self: *PipeStream = @ptrCast(@alignCast(context.?));
        self.task_queued = false;
        self.freeIfDone();
    }

    fn cancel(ctx: ?*anyopaque, realm: js.Realm, _: *runtime.Instance, _: js.Value) js.Error!js.Value {
        const self: *PipeStream = @ptrCast(@alignCast(ctx.?));
        // Nobody will read what is left: let the pipe go, which stops the
        // transfer if this was its last reader.
        self.releasePipe();
        return realm.promiseResolvedWithUndefined();
    }

    fn deinitSource(ctx: ?*anyopaque, allocator: std.mem.Allocator) void {
        _ = allocator;
        const self: *PipeStream = @ptrCast(@alignCast(ctx.?));
        self.detached = true;
        self.controller = null;
        self.releasePipe();
        if (self.pending_pull) |d| {
            self.pending_pull = null;
            d.deinit();
        }
        self.freeIfDone();
    }

    fn releasePipe(self: *PipeStream) void {
        const pipe = self.pipe orelse return;
        self.pipe = null;
        pipe.consumer = null;
        pipe.release();
    }

    fn freeIfDone(self: *PipeStream) void {
        if (!self.detached or self.task_queued or self.busy > 0) return;
        self.allocator.destroy(self);
    }
};

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
