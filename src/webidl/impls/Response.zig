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
        internal.response.deinit();
        allocator.destroy(internal);
    }
    runtime.Instance.deinit(instance);
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
    }

    // Set default statusText based on status if not explicitly provided
    if (!status_text_provided) {
        internal.response.status_message = getDefaultStatusText(internal.response.status);
    }

    // Handle body parameter
    if (body.wasPassed()) {
        if (body.value) |body_init| {
            // Extract body bytes based on BodyInit variant
            const body_bytes: ?[]const u8 = switch (body_init) {
                .string => |s| s,
                .buffer => |b| b,
                // For opaque types, we can't extract bytes yet
                .blob_ptr, .form_data_ptr, .url_search_params_ptr, .readable_stream_ptr, .v8_value => null,
            };

            if (body_bytes) |bytes| {
                if (bytes.len > 0) {
                    // Create Body from bytes
                    const fetch_body = fetch.internal.Body.fromBytes(allocator, bytes) catch {
                        return error.OutOfMemory;
                    };
                    internal.response.body = fetch_body;

                    // Set Content-Type header if not already set and body is string
                    if (body_init == .string) {
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

pub fn call_error(instance: *runtime.Instance) ImplError!*runtime.Instance {
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

pub fn call_redirect(instance: *runtime.Instance, url: runtime.USVString, status: webidl.Opt(u16)) ImplError!*runtime.Instance {
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
pub fn call_json_static(instance: *runtime.Instance, data: *const anyopaque, init_data: webidl.Opt(dictionaries.ResponseInit)) ImplError!*runtime.Instance {
    _ = data;

    // Static method - use context directly, not instance state
    const allocator = instance.ctx.allocator;
    const ctx = instance.ctx;

    // Create an empty body (TODO: serialize data to JSON)
    const empty_body = typedefs.BodyInit{ .string = "" };
    // Wrap body in Opt for call_constructor which expects Opt(?BodyInit)
    const body_opt = webidl.Opt(?typedefs.BodyInit).passed(empty_body);
    const json_instance = try call_constructor(allocator, ctx, body_opt, init_data);
    const json_state = json_instance.getState(State);
    const internal = json_state.own._internal.?;

    try internal.response.header_list.set("Content-Type", "application/json");

    return json_instance;
}

// === Property Getters ===

pub fn get_type(instance: *runtime.Instance) ImplError!enums.ResponseType {
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

pub fn get_url(instance: *runtime.Instance) ImplError!runtime.USVString {
    const state = instance.getState(State);
    const internal = state.own._internal.?;

    // Return last URL in URL list (for redirects)
    if (internal.response.url_list.items.len > 0) {
        return internal.response.url_list.items[internal.response.url_list.items.len - 1];
    }

    return "";
}

pub fn get_redirected(instance: *runtime.Instance) ImplError!bool {
    const state = instance.getState(State);
    const internal = state.own._internal.?;
    return internal.response.url_list.items.len > 1;
}

pub fn get_status(instance: *runtime.Instance) ImplError!u16 {
    const state = instance.getState(State);
    const internal = state.own._internal.?;
    return internal.response.status;
}

pub fn get_ok(instance: *runtime.Instance) ImplError!bool {
    const state = instance.getState(State);
    const internal = state.own._internal.?;
    return internal.response.status >= 200 and internal.response.status <= 299;
}

pub fn get_statusText(instance: *runtime.Instance) ImplError!runtime.ByteString {
    const state = instance.getState(State);
    const internal = state.own._internal.?;
    return internal.response.status_message;
}

pub fn get_headers(instance: *runtime.Instance) ImplError!*runtime.Instance {
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

pub fn get_body(instance: *runtime.Instance) ImplError!?*runtime.Instance {
    const state = instance.getState(State);
    return state.own.body;
}

pub fn get_bodyUsed(instance: *runtime.Instance) ImplError!bool {
    const state = instance.getState(State);
    return state.own.bodyUsed;
}

// === Methods - STUBS (Option A) ===

/// clone() - Clones the Response
/// Spec: https://fetch.spec.whatwg.org/#dom-response-clone
pub fn call_clone(instance: *runtime.Instance) ImplError!*runtime.Instance {
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
pub fn call_arrayBuffer(instance: *runtime.Instance) ImplError!*const anyopaque {
    const state = instance.getState(State);
    const internal = state.own._internal.?;

    const event_loop = instance.ctx.getEventLoop() catch {
        return error.InvalidState;
    };

    const AsyncPromise = @import("streams_async_promise").AsyncPromise;
    const ArrayBufferView = @import("runtime").arraybuffer_view;
    var promise = try AsyncPromise(ArrayBufferView.ArrayBuffer).init(
        internal.allocator,
        event_loop,
    );

    if (internal.response.body) |body| {
        if (body.isDisturbed()) {
            const exception = @import("webidl").errors.Exception{
                .simple = .{ .type = .TypeError, .message = "Body is unusable (already read)" },
            };
            promise.reject(exception);
        } else {
            const bytes = body.readAllBytes() catch {
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
    } else {
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
    const file_mod = @import("file");
    const BlobData = file_mod.BlobData;
    var promise = try AsyncPromise(*runtime.Instance).init(
        internal.allocator,
        event_loop,
    );

    // Get MIME type from Content-Type header
    const mime_type = blk: {
        const ct = internal.response.header_list.get(internal.allocator, "content-type") catch null;
        break :blk ct orelse "";
    };

    if (internal.response.body) |body| {
        if (body.isDisturbed()) {
            const exception = @import("webidl").errors.Exception{
                .simple = .{ .type = .TypeError, .message = "Body is unusable (already read)" },
            };
            promise.reject(exception);
        } else {
            const bytes = body.readAllBytes() catch {
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
    } else {
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

    const event_loop = instance.ctx.getEventLoop() catch {
        return error.InvalidState;
    };

    const AsyncPromise = @import("streams_async_promise").AsyncPromise;
    var promise = try AsyncPromise([]const u8).init(
        internal.allocator,
        event_loop,
    );

    if (internal.response.body) |body| {
        if (body.isDisturbed()) {
            const exception = @import("webidl").errors.Exception{
                .simple = .{ .type = .TypeError, .message = "Body is unusable (already read)" },
            };
            promise.reject(exception);
        } else {
            const bytes = body.readAllBytes() catch {
                const exception = @import("webidl").errors.Exception{
                    .simple = .{ .type = .TypeError, .message = "Failed to read body" },
                };
                promise.reject(exception);
                return @ptrCast(promise);
            };

            const bytes_copy = try internal.allocator.dupe(u8, bytes);
            promise.fulfill(bytes_copy);
        }
    } else {
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
    const content_type = internal.response.header_list.get(internal.allocator, "content-type") catch null;

    if (internal.response.body) |body| {
        if (body.isDisturbed()) {
            const exception = @import("webidl").errors.Exception{
                .simple = .{ .type = .TypeError, .message = "Body is unusable (already read)" },
            };
            promise.reject(exception);
            return @ptrCast(promise);
        }

        const bytes = body.readAllBytes() catch {
            const exception = @import("webidl").errors.Exception{
                .simple = .{ .type = .TypeError, .message = "Failed to read body" },
            };
            promise.reject(exception);
            return @ptrCast(promise);
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
                    .simple = .{ .type = .TypeError, .message = "Invalid Content-Type for FormData" },
                };
                promise.reject(exception);
                return @ptrCast(promise);
            }
        } else url_blk: {
            // No Content-Type - default to URL-encoded
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
/// This is the instance method from the Body mixin
/// Spec: https://fetch.spec.whatwg.org/#dom-body-json
pub fn call_json(instance: *runtime.Instance) ImplError!*const anyopaque {
    const state = instance.getState(State);
    const internal = state.own._internal.?;

    const event_loop = instance.ctx.getEventLoop() catch {
        return error.InvalidState;
    };

    const AsyncPromise = @import("streams_async_promise").AsyncPromise;
    var promise = try AsyncPromise(std.json.Value).init(
        internal.allocator,
        event_loop,
    );

    if (internal.response.body) |body| {
        if (body.isDisturbed()) {
            const exception = @import("webidl").errors.Exception{
                .simple = .{ .type = .TypeError, .message = "Body is unusable (already read)" },
            };
            promise.reject(exception);
        } else {
            const bytes = body.readAllBytes() catch {
                const exception = @import("webidl").errors.Exception{
                    .simple = .{ .type = .TypeError, .message = "Failed to read body" },
                };
                promise.reject(exception);
                return @ptrCast(promise);
            };

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
    } else {
        const exception = @import("webidl").errors.Exception{
            .simple = .{ .type = .SyntaxError, .message = "Unexpected end of JSON input" },
        };
        promise.reject(exception);
    }

    return @ptrCast(promise);
}

/// text() - Returns promise fulfilled with body as string
/// Spec: https://fetch.spec.whatwg.org/#dom-body-text
///
/// Uses the engine abstraction layer for Promise creation and string creation.
pub fn call_text(instance: *runtime.Instance) ImplError!*const anyopaque {
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

    // Return the JS Promise object
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
