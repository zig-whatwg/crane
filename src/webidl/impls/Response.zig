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

/// Constructor - STUB: Does not parse body/init properly (Option A)
pub fn call_constructor(
    allocator: std.mem.Allocator,
    ctx: runtime.Context,
    body: typedefs.BodyInit,
    init_data: dictionaries.ResponseInit,
) !*runtime.Instance {
    const instance = try init(allocator, State, &Response.vtable, ctx);
    errdefer deinit(instance);

    const state = instance.getState(State);
    const internal = state.own._internal.?;

    if (init_data.status) |status| {
        if (status < 200 or status > 599) {
            return error.RangeError;
        }
        internal.response.status = status;
    }

    if (init_data.statusText) |status_text| {
        internal.response.status_message = status_text;
    }

    _ = body;
    return instance;
}

// === Static Methods ===

pub fn call_error(instance: *runtime.Instance) !*runtime.Instance {
    const state = instance.getState(State);
    const allocator = state.own._internal.?.allocator;
    const ctx = instance.ctx;

    const error_instance = try init(allocator, State, &Response.vtable, ctx);
    const error_state = error_instance.getState(State);
    const internal = error_state.own._internal.?;

    internal.response.response_type = .@"error";
    internal.response.status = 0;

    return error_instance;
}

pub fn call_redirect(instance: *runtime.Instance, url: []const u8, status: u16) !*runtime.Instance {
    if (status != 301 and status != 302 and status != 303 and status != 307 and status != 308) {
        return error.RangeError;
    }

    const state = instance.getState(State);
    const allocator = state.own._internal.?.allocator;
    const ctx = instance.ctx;

    const redirect_instance = try init(allocator, State, &Response.vtable, ctx);
    const redirect_state = redirect_instance.getState(State);
    const internal = redirect_state.own._internal.?;

    internal.response.status = status;
    try internal.response.header_list.append("Location", url);

    return redirect_instance;
}

pub fn call_json(instance: *runtime.Instance, data: *const anyopaque, init_data: dictionaries.ResponseInit) !*runtime.Instance {
    _ = data;

    const state = instance.getState(State);
    const allocator = state.own._internal.?.allocator;
    const ctx = instance.ctx;

    const dummy: u8 = 0;
    const empty_body = typedefs.BodyInit{ .variant_0 = @as(*const anyopaque, @ptrCast(&dummy)) };
    const json_instance = try call_constructor(allocator, ctx, empty_body, init_data);
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

pub fn get_url(instance: *runtime.Instance) ImplError![]const u8 {
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

pub fn get_statusText(instance: *runtime.Instance) ImplError![]const u8 {
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
pub fn call_blob(instance: *runtime.Instance) ImplError!*runtime.Instance {
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
pub fn call_formData(instance: *runtime.Instance) ImplError!*runtime.Instance {
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

    // TODO: Implement full FormData parsing
    // Requires parsing multipart/form-data or application/x-www-form-urlencoded
    // This is a complex operation that should be implemented when the full
    // FormData WebIDL wrapper is ready
    const exception = @import("webidl").errors.Exception{
        .simple = .{ .type = .TypeError, .message = "FormData parsing not yet implemented - requires full parser" },
    };
    promise.reject(exception);

    return @ptrCast(promise);
}

/// json() - Returns promise fulfilled with body parsed as JSON
/// Spec: https://fetch.spec.whatwg.org/#dom-body-json
pub fn call_json_read(instance: *runtime.Instance) ImplError!*const anyopaque {
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
pub fn call_text(instance: *runtime.Instance) ImplError!*const anyopaque {
    const state = instance.getState(State);
    const internal = state.own._internal.?;

    const event_loop = instance.ctx.getEventLoop() catch {
        return error.InvalidState;
    };

    const AsyncPromise = @import("streams_async_promise").AsyncPromise;
    var promise = try AsyncPromise(runtime.USVString).init(
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

            const text = try internal.allocator.dupe(u8, bytes);
            promise.fulfill(text);
        }
    } else {
        const empty = try internal.allocator.alloc(u8, 0);
        promise.fulfill(empty);
    }

    return @ptrCast(promise);
}
