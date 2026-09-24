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
    const has_body = if (internal.response.body) |body_obj| blk: {
        break :blk body_obj.data.items.len > 0 or body_obj.source != .none;
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
    if (internal.response.body) |body| {
        if (body.isDisturbed()) {
            return error.TypeError;
        }
    }

    // Step 2: Clone the internal response
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
