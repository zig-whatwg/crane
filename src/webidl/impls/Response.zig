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

    const internal = try allocator.create(InternalState);
    errdefer allocator.destroy(internal);

    const response = try InternalResponse.init(allocator);
    errdefer response.deinit();

    internal.* = .{
        .allocator = allocator,
        .response = response,
        .headers_cache = null,
    };

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
        // header strings - Response.response.deinit() will. The Headers instance
        // itself is in the wrapper cache and will be cleaned up by GC.
        // We don't explicitly call Headers.deinit here to avoid order-of-destruction
        // issues - let the wrapper cache handle it.
        internal.headers_cache = null;

        internal.response.deinit();
        allocator.destroy(internal);
    }
    // NOTE: Do NOT call runtime.Instance.deinit(instance) here!
    // The GC integration layer handles slab freeing after this returns.
}

/// Constructor - Creates a Response with optional body and init
/// Spec: https://fetch.spec.whatwg.org/#dom-response
pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, body: webidl.Opt(?typedefs.BodyInit), init_data: webidl.Opt(dictionaries.ResponseInit)) !*runtime.Instance {
    const instance = try init(allocator, State, &Response.vtable, ctx);
    errdefer deinit(instance);

    const state = instance.getState(State);
    const internal = state.own._internal.?;

    // Handle init options first (status, statusText, headers)
    var status_text_provided = false;
    if (init_data.wasPassed()) {
        if (init_data.value.status) |status| {
            if (status < 200 or status > 599) {
                return error.RangeError;
            }
            internal.response.status = status;
        }

        if (init_data.value.statusText) |status_text| {
            internal.response.status_message = status_text;
            status_text_provided = true;
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

    // Set default statusText based on status if not explicitly provided
    if (!status_text_provided) {
        internal.response.status_message = getDefaultStatusText(internal.response.status);
    }

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
                    const fetch_body = fetch.internal.Body.fromBytes(allocator, bytes) catch {
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

pub fn call_error(instance: *runtime.Instance) anyerror!*runtime.Instance {
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

pub fn call_redirect(instance: *runtime.Instance, url: runtime.USVString, status: webidl.Opt(u16)) anyerror!*runtime.Instance {
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
pub fn call_json_static(allocator: std.mem.Allocator, ctx: runtime.Context, data: runtime.JSValue, init_data: webidl.Opt(dictionaries.ResponseInit)) anyerror!*runtime.Instance {
    // Step 1: Let bytes be the result of running serialize a JavaScript value to JSON bytes on data
    // For now, convert JSValue to string representation
    const body_bytes: []const u8 = switch (data) {
        .string => |s| s.data,
        .boolean => |b| if (b) "true" else "false",
        .null => "null",
        .undefined => "undefined",
        .number => |_| "0", // TODO: proper number serialization
        else => "{}",
    };

    // Create a body from the JSON bytes
    const body = typedefs.BodyInit{ .xmlhttp_request_body_init = .{ .usvstring = body_bytes } };
    const body_opt = webidl.Opt(?typedefs.BodyInit).passed(body);
    const json_instance = try call_constructor(allocator, ctx, body_opt, init_data);
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

pub fn get_url(instance: *runtime.Instance) anyerror!runtime.USVString {
    const state = instance.getState(State);
    const internal = state.own._internal.?;

    // Return last URL in URL list (for redirects)
    if (internal.response.url_list.items.len > 0) {
        return internal.response.url_list.items[internal.response.url_list.items.len - 1];
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

pub fn get_statusText(instance: *runtime.Instance) anyerror!runtime.ByteString {
    const state = instance.getState(State);
    const internal = state.own._internal.?;
    return internal.response.status_message;
}

pub fn get_headers(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const state = instance.getState(State);
    const internal = state.own._internal.?;

    // Return cached instance if exists
    if (internal.headers_cache) |headers| {
        return headers;
    }

    // Create Headers instance wrapping our header_list with "response" guard
    const Headers = @import("Headers.zig");
    const headers = try Headers.initWithHeaderList(
        internal.allocator,
        instance.ctx,
        &internal.response.header_list,
        .response,
    );

    // Cache it
    internal.headers_cache = headers;

    return headers;
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
    const allocator = internal.allocator;
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
        allocator,
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
pub fn call_arrayBuffer(instance: *runtime.Instance) anyerror!*const anyopaque {
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
            return engine.getPromiseObject(promise_handle);
        }
    }

    // Get body bytes
    const body_bytes: []const u8 = if (internal.response.body) |body| blk: {
        const bytes = body.readAllBytes() catch |err| {
            engine.rejectPromise(engine_ctx, promise_handle, err) catch {};
            return engine.getPromiseObject(promise_handle);
        };
        break :blk bytes;
    } else "";

    // Create JS ArrayBuffer through engine abstraction
    const createArrayBuffer = engine.createArrayBuffer orelse {
        engine.rejectPromise(engine_ctx, promise_handle, error.InvalidState) catch {};
        return engine.getPromiseObject(promise_handle);
    };

    const js_array_buffer = createArrayBuffer(engine_ctx, body_bytes) catch {
        engine.rejectPromise(engine_ctx, promise_handle, error.InvalidState) catch {};
        return engine.getPromiseObject(promise_handle);
    };

    // Resolve with the JS ArrayBuffer
    engine.resolvePromise(engine_ctx, promise_handle, js_array_buffer) catch {
        return error.InvalidState;
    };

    return engine.getPromiseObject(promise_handle);
}

/// blob() - Returns promise fulfilled with body as Blob
/// Spec: https://fetch.spec.whatwg.org/#dom-body-blob
///
/// Uses the engine abstraction layer for Promise creation and instance wrapping.
pub fn call_blob(instance: *runtime.Instance) anyerror!*const anyopaque {
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
            return engine.getPromiseObject(promise_handle);
        }
    }

    // Get body bytes
    const body_bytes: []const u8 = if (internal.response.body) |body| blk: {
        const bytes = body.readAllBytes() catch |err| {
            engine.rejectPromise(engine_ctx, promise_handle, err) catch {};
            return engine.getPromiseObject(promise_handle);
        };
        break :blk bytes;
    } else "";

    // Create Blob instance
    const blob_data = BlobData.init(internal.allocator, body_bytes, mime_type) catch {
        engine.rejectPromise(engine_ctx, promise_handle, error.OutOfMemory) catch {};
        return engine.getPromiseObject(promise_handle);
    };

    const blob_instance = BlobImpl.createFromBlobData(
        internal.allocator,
        instance.ctx,
        blob_data,
    ) catch {
        blob_data.deinit();
        engine.rejectPromise(engine_ctx, promise_handle, error.OutOfMemory) catch {};
        return engine.getPromiseObject(promise_handle);
    };

    // Wrap the Blob instance as a V8 object
    const wrapInstance = engine.wrapInstance orelse {
        engine.rejectPromise(engine_ctx, promise_handle, error.InvalidState) catch {};
        return engine.getPromiseObject(promise_handle);
    };

    const js_blob = wrapInstance(engine_ctx, blob_instance) catch {
        engine.rejectPromise(engine_ctx, promise_handle, error.InvalidState) catch {};
        return engine.getPromiseObject(promise_handle);
    };

    // Resolve with the JS Blob
    engine.resolvePromise(engine_ctx, promise_handle, js_blob) catch {
        return error.InvalidState;
    };

    return engine.getPromiseObject(promise_handle);
}

/// bytes() - Returns promise fulfilled with body as Uint8Array
/// Spec: https://fetch.spec.whatwg.org/#dom-body-bytes
///
/// Uses the engine abstraction layer for Promise and Uint8Array creation.
pub fn call_bytes(instance: *runtime.Instance) anyerror!*const anyopaque {
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
            return engine.getPromiseObject(promise_handle);
        }
    }

    // Get body bytes
    const body_bytes: []const u8 = if (internal.response.body) |body| blk: {
        const bytes = body.readAllBytes() catch |err| {
            engine.rejectPromise(engine_ctx, promise_handle, err) catch {};
            return engine.getPromiseObject(promise_handle);
        };
        break :blk bytes;
    } else "";

    // Create JS Uint8Array through engine abstraction
    const createUint8Array = engine.createUint8Array orelse {
        engine.rejectPromise(engine_ctx, promise_handle, error.InvalidState) catch {};
        return engine.getPromiseObject(promise_handle);
    };

    const js_uint8_array = createUint8Array(engine_ctx, body_bytes) catch {
        engine.rejectPromise(engine_ctx, promise_handle, error.InvalidState) catch {};
        return engine.getPromiseObject(promise_handle);
    };

    // Resolve with the JS Uint8Array
    engine.resolvePromise(engine_ctx, promise_handle, js_uint8_array) catch {
        return error.InvalidState;
    };

    return engine.getPromiseObject(promise_handle);
}

/// formData() - Returns promise fulfilled with body as FormData
/// Spec: https://fetch.spec.whatwg.org/#dom-body-formdata
///
/// Uses the engine abstraction layer for Promise creation and instance wrapping.
pub fn call_formData(instance: *runtime.Instance) anyerror!*const anyopaque {
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

    // Helper to reject and return
    const rejectAndReturn = struct {
        fn call(eng: anytype, eng_ctx: anytype, handle: anytype, err: anyerror) *const anyopaque {
            eng.rejectPromise(eng_ctx, handle, err) catch {};
            return eng.getPromiseObject(handle);
        }
    }.call;

    // Get Content-Type header
    const content_type = internal.response.header_list.get(internal.allocator, "content-type") catch null;

    // Check for disturbed body
    if (internal.response.body) |body| {
        if (body.isDisturbed()) {
            return rejectAndReturn(engine, engine_ctx, promise_handle, error.TypeError);
        }
    }

    // Get body bytes
    const body_bytes: []const u8 = if (internal.response.body) |body| blk: {
        const bytes = body.readAllBytes() catch {
            return rejectAndReturn(engine, engine_ctx, promise_handle, error.TypeError);
        };
        break :blk bytes;
    } else "";

    // Parse body into FormData based on Content-Type
    const form_data: *xhr.form_data.FormData = if (body_bytes.len > 0) parse_blk: {
        if (content_type) |ct| {
            if (std.mem.indexOf(u8, ct, "multipart/form-data") != null) {
                const boundary = multipart_parser.extractBoundary(internal.allocator, ct) catch {
                    return rejectAndReturn(engine, engine_ctx, promise_handle, error.TypeError);
                };
                defer internal.allocator.free(boundary);

                const entries = multipart_parser.parseMultipartFormData(internal.allocator, body_bytes, boundary) catch {
                    return rejectAndReturn(engine, engine_ctx, promise_handle, error.TypeError);
                };
                defer {
                    for (entries) |*entry| entry.deinit(internal.allocator);
                    internal.allocator.free(entries);
                }

                const fd = xhr.form_data.FormData.init(internal.allocator) catch {
                    return rejectAndReturn(engine, engine_ctx, promise_handle, error.OutOfMemory);
                };
                errdefer fd.deinit();

                for (entries) |entry| {
                    switch (entry.value) {
                        .string => |s| fd.appendString(entry.name, s) catch {
                            return rejectAndReturn(engine, engine_ctx, promise_handle, error.OutOfMemory);
                        },
                        .file => |f| fd.appendFile(entry.name, f, entry.filename) catch {
                            return rejectAndReturn(engine, engine_ctx, promise_handle, error.OutOfMemory);
                        },
                        .blob_instance => |ptr| fd.appendBlobInstance(entry.name, ptr, entry.filename) catch {
                            return rejectAndReturn(engine, engine_ctx, promise_handle, error.OutOfMemory);
                        },
                    }
                }

                break :parse_blk fd;
            } else if (std.mem.indexOf(u8, ct, "application/x-www-form-urlencoded") != null) {
                const tuples = url_parser.parse(internal.allocator, body_bytes) catch {
                    return rejectAndReturn(engine, engine_ctx, promise_handle, error.TypeError);
                };
                defer {
                    for (tuples) |tuple| tuple.deinit(internal.allocator);
                    internal.allocator.free(tuples);
                }

                const fd = xhr.form_data.FormData.init(internal.allocator) catch {
                    return rejectAndReturn(engine, engine_ctx, promise_handle, error.OutOfMemory);
                };
                errdefer fd.deinit();

                for (tuples) |tuple| {
                    fd.appendString(tuple.name, tuple.value) catch {
                        return rejectAndReturn(engine, engine_ctx, promise_handle, error.OutOfMemory);
                    };
                }

                break :parse_blk fd;
            } else {
                return rejectAndReturn(engine, engine_ctx, promise_handle, error.TypeError);
            }
        } else {
            const tuples = url_parser.parse(internal.allocator, body_bytes) catch {
                return rejectAndReturn(engine, engine_ctx, promise_handle, error.TypeError);
            };
            defer {
                for (tuples) |tuple| tuple.deinit(internal.allocator);
                internal.allocator.free(tuples);
            }

            const fd = xhr.form_data.FormData.init(internal.allocator) catch {
                return rejectAndReturn(engine, engine_ctx, promise_handle, error.OutOfMemory);
            };
            errdefer fd.deinit();

            for (tuples) |tuple| {
                fd.appendString(tuple.name, tuple.value) catch {
                    return rejectAndReturn(engine, engine_ctx, promise_handle, error.OutOfMemory);
                };
            }

            break :parse_blk fd;
        }
    } else empty_blk: {
        break :empty_blk xhr.form_data.FormData.init(internal.allocator) catch {
            return rejectAndReturn(engine, engine_ctx, promise_handle, error.OutOfMemory);
        };
    };

    // Create FormData WebIDL instance
    const formdata_instance = FormDataImpl.createFromInternal(
        internal.allocator,
        instance.ctx,
        form_data,
    ) catch {
        form_data.deinit();
        return rejectAndReturn(engine, engine_ctx, promise_handle, error.OutOfMemory);
    };

    // Wrap the FormData instance as a V8 object
    const wrapInstance = engine.wrapInstance orelse {
        return rejectAndReturn(engine, engine_ctx, promise_handle, error.InvalidState);
    };

    const js_formdata = wrapInstance(engine_ctx, formdata_instance) catch {
        return rejectAndReturn(engine, engine_ctx, promise_handle, error.InvalidState);
    };

    // Resolve with the JS FormData
    engine.resolvePromise(engine_ctx, promise_handle, js_formdata) catch {
        return error.InvalidState;
    };

    return engine.getPromiseObject(promise_handle);
}

/// json() - Returns promise fulfilled with body parsed as JSON
/// This is the instance method from the Body mixin
/// Spec: https://fetch.spec.whatwg.org/#dom-body-json
///
/// Uses the engine abstraction layer for Promise and JSON parsing.
pub fn call_json(instance: *runtime.Instance) anyerror!*const anyopaque {
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
            return engine.getPromiseObject(promise_handle);
        }
    }

    // Get body bytes
    const body_bytes: []const u8 = if (internal.response.body) |body| blk: {
        const bytes = body.readAllBytes() catch |err| {
            engine.rejectPromise(engine_ctx, promise_handle, err) catch {};
            return engine.getPromiseObject(promise_handle);
        };
        break :blk bytes;
    } else {
        // Null body - reject with SyntaxError (empty JSON is invalid)
        engine.rejectPromise(engine_ctx, promise_handle, error.SyntaxError) catch {};
        return engine.getPromiseObject(promise_handle);
    };

    // Parse JSON through engine abstraction
    const parseJson = engine.parseJson orelse {
        engine.rejectPromise(engine_ctx, promise_handle, error.InvalidState) catch {};
        return engine.getPromiseObject(promise_handle);
    };

    const js_value = parseJson(engine_ctx, body_bytes) catch {
        // JSON parse failed - reject with SyntaxError
        engine.rejectPromise(engine_ctx, promise_handle, error.SyntaxError) catch {};
        return engine.getPromiseObject(promise_handle);
    };

    // Resolve with the parsed JS value
    engine.resolvePromise(engine_ctx, promise_handle, js_value) catch {
        return error.InvalidState;
    };

    return engine.getPromiseObject(promise_handle);
}

/// text() - Returns promise fulfilled with body as string
/// Spec: https://fetch.spec.whatwg.org/#dom-body-text
///
/// Uses the engine abstraction layer for Promise creation and string creation.
pub fn call_text(instance: *runtime.Instance) anyerror!*const anyopaque {
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
            return engine.getPromiseObject(promise_handle);
        }
    }

    // Get body text
    const body_text: []const u8 = if (internal.response.body) |body| blk: {
        const bytes = body.readAllBytes() catch |err| {
            // Reject on read error
            engine.rejectPromise(engine_ctx, promise_handle, err) catch {};
            return engine.getPromiseObject(promise_handle);
        };
        break :blk bytes;
    } else "";

    // Create JS string through engine abstraction
    const createString = engine.createString orelse {
        // No createString support - resolve with null (undefined)
        engine.resolvePromise(engine_ctx, promise_handle, null) catch {};
        return engine.getPromiseObject(promise_handle);
    };

    const js_string = createString(engine_ctx, body_text) catch {
        engine.rejectPromise(engine_ctx, promise_handle, error.InvalidState) catch {};
        return engine.getPromiseObject(promise_handle);
    };

    // Resolve with the JS string
    engine.resolvePromise(engine_ctx, promise_handle, js_string) catch {
        return error.InvalidState;
    };

    // Return the JS Promise object wrapped in Promise(T) type
    return engine.getPromiseObject(promise_handle);
}

// === Helper Functions ===

/// Get default status text for HTTP status codes
fn getDefaultStatusText(status: u16) []const u8 {
    return switch (status) {
        100 => "Continue",
        101 => "Switching Protocols",
        200 => "OK",
        201 => "Created",
        202 => "Accepted",
        203 => "Non-Authoritative Information",
        204 => "No Content",
        205 => "Reset Content",
        206 => "Partial Content",
        300 => "Multiple Choices",
        301 => "Moved Permanently",
        302 => "Found",
        303 => "See Other",
        304 => "Not Modified",
        307 => "Temporary Redirect",
        308 => "Permanent Redirect",
        400 => "Bad Request",
        401 => "Unauthorized",
        403 => "Forbidden",
        404 => "Not Found",
        405 => "Method Not Allowed",
        406 => "Not Acceptable",
        408 => "Request Timeout",
        409 => "Conflict",
        410 => "Gone",
        411 => "Length Required",
        412 => "Precondition Failed",
        413 => "Payload Too Large",
        414 => "URI Too Long",
        415 => "Unsupported Media Type",
        416 => "Range Not Satisfiable",
        417 => "Expectation Failed",
        418 => "I'm a teapot",
        422 => "Unprocessable Entity",
        429 => "Too Many Requests",
        500 => "Internal Server Error",
        501 => "Not Implemented",
        502 => "Bad Gateway",
        503 => "Service Unavailable",
        504 => "Gateway Timeout",
        505 => "HTTP Version Not Supported",
        else => "",
    };
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
