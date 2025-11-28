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
    return state.own.headers;
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

pub fn call_clone(instance: *runtime.Instance) ImplError!*runtime.Instance {
    _ = instance;
    return error.InvalidState;
}

pub fn call_arrayBuffer(instance: *runtime.Instance) ImplError!*const anyopaque {
    _ = instance;
    return error.InvalidState;
}

pub fn call_blob(instance: *runtime.Instance) ImplError!*runtime.Instance {
    _ = instance;
    return error.InvalidState;
}

pub fn call_bytes(instance: *runtime.Instance) ImplError!*const anyopaque {
    _ = instance;
    return error.InvalidState;
}

pub fn call_formData(instance: *runtime.Instance) ImplError!*runtime.Instance {
    _ = instance;
    return error.InvalidState;
}

pub fn call_json_read(instance: *runtime.Instance) ImplError!*const anyopaque {
    _ = instance;
    return error.InvalidState;
}

pub fn call_text(instance: *runtime.Instance) ImplError!*const anyopaque {
    _ = instance;
    return error.InvalidState;
}
