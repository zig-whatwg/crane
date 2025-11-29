//! Implementation for Headers interface
//!
//! Wraps Fetch internal HeaderList to provide WebIDL interface.
//! Spec: https://fetch.spec.whatwg.org/#headers-class

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");

// Import Fetch internal structures
const fetch = @import("fetch");
const webidl = @import("webidl");
const HeaderList = fetch.internal.HeaderList;
const HeaderGuard = fetch.internal.HeaderGuard;
const validation = fetch.internal.validation;

const Headers = interfaces.Headers;

pub const State = Headers.State;

pub const ImplError = error{
    OutOfMemory,
    TypeError,
    InvalidHeader,
};

/// Internal state wraps Fetch HeaderList
pub const InternalState = struct {
    allocator: std.mem.Allocator,
    header_list: HeaderList,
    guard: HeaderGuard,
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

    internal.* = .{
        .allocator = allocator,
        .header_list = HeaderList.init(allocator),
        .guard = .none,
    };

    // Store in instance
    const state = instance.getState(StateType);
    state.own._internal = internal;

    return instance;
}

/// Initialize with existing HeaderList and guard (for Request/Response)
pub fn initWithHeaderList(
    allocator: std.mem.Allocator,
    ctx: runtime.Context,
    header_list: *HeaderList,
    guard: HeaderGuard,
) !*runtime.Instance {
    const instance = try runtime.Instance.init(allocator, State, &Headers.vtable, ctx);
    errdefer runtime.Instance.deinit(instance);

    // Create internal state that wraps existing header list
    const internal = try allocator.create(InternalState);
    errdefer allocator.destroy(internal);

    internal.* = .{
        .allocator = allocator,
        .header_list = header_list.*, // Copy the header list
        .guard = guard,
    };

    // Store in instance
    const state = instance.getState(State);
    state.own._internal = internal;

    return instance;
}

/// Deinitialize
pub fn deinit(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        const allocator = internal.allocator;
        internal.header_list.deinit();
        allocator.destroy(internal);
    }
    runtime.Instance.deinit(instance);
}

/// Constructor
pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, init_data: webidl.Opt(typedefs.HeadersInit)) !*runtime.Instance {
    const instance = try init(allocator, State, &Headers.vtable, ctx);
    errdefer deinit(instance);

    // Populate from init data
    // HeadersInit is a union in the typedef
    // For now, we handle empty initialization
    // Full init handling would require parsing the init_data union
    _ = init_data;

    return instance;
}

/// append(name, value)
pub fn call_append(instance: *runtime.Instance, name: runtime.ByteString, value: runtime.ByteString) ImplError!void {
    const state = instance.getState(State);
    const internal = state.own._internal.?;

    // Validate name and value
    if (!validation.isValidHeaderName(name)) {
        return error.TypeError;
    }
    if (!validation.isValidHeaderValue(value)) {
        return error.TypeError;
    }

    // Check guard
    if (!canMutate(internal, name)) {
        return; // Silently fail per spec
    }

    // Delegate to HeaderList
    try internal.header_list.append(name, value);
}

/// delete(name)
pub fn call_delete(instance: *runtime.Instance, name: runtime.ByteString) ImplError!void {
    const state = instance.getState(State);
    const internal = state.own._internal.?;

    // Validate name
    if (!validation.isValidHeaderName(name)) {
        return error.TypeError;
    }

    // Check guard
    if (!canMutate(internal, name)) {
        return; // Silently fail per spec
    }

    // Delegate to HeaderList
    internal.header_list.delete(name);
}

/// get(name) -> ByteString?
pub fn call_get(instance: *runtime.Instance, name: runtime.ByteString) ImplError!?runtime.ByteString {
    const state = instance.getState(State);
    const internal = state.own._internal.?;

    // Validate name
    if (!validation.isValidHeaderName(name)) {
        return error.TypeError;
    }

    // Delegate to HeaderList
    return internal.header_list.get(internal.allocator, name) catch |err| {
        return switch (err) {
            error.OutOfMemory => error.OutOfMemory,
        };
    };
}

/// getSetCookie() -> sequence<ByteString>
pub fn call_getSetCookie(instance: *runtime.Instance) ImplError!*const anyopaque {
    const state = instance.getState(State);
    const internal = state.own._internal.?;

    // Get all Set-Cookie headers
    const values = internal.header_list.getSetCookie(internal.allocator) catch |err| {
        return switch (err) {
            error.OutOfMemory => error.OutOfMemory,
        };
    };

    // Return as opaque pointer (V8 will handle conversion)
    return @ptrCast(values.ptr);
}

/// has(name) -> boolean
pub fn call_has(instance: *runtime.Instance, name: runtime.ByteString) ImplError!bool {
    const state = instance.getState(State);
    const internal = state.own._internal.?;

    // Validate name
    if (!validation.isValidHeaderName(name)) {
        return error.TypeError;
    }

    return internal.header_list.contains(name);
}

/// set(name, value)
pub fn call_set(instance: *runtime.Instance, name: runtime.ByteString, value: runtime.ByteString) ImplError!void {
    const state = instance.getState(State);
    const internal = state.own._internal.?;

    // Validate name and value
    if (!validation.isValidHeaderName(name)) {
        return error.TypeError;
    }
    if (!validation.isValidHeaderValue(value)) {
        return error.TypeError;
    }

    // Check guard
    if (!canMutate(internal, name)) {
        return; // Silently fail per spec
    }

    // Delegate to HeaderList
    try internal.header_list.set(name, value);
}

/// forEach(callback)
/// Iterator support - called by V8 for Symbol.iterator
pub fn call_forEach(instance: *runtime.Instance, callback: *const anyopaque) ImplError!void {
    const state = instance.getState(State);
    const internal = state.own._internal.?;

    // Iterate over headers
    for (internal.header_list.entries.items) |entry| {
        // Call the callback with (value, name, headers)
        // V8 runtime will handle the actual callback invocation
        _ = callback;
        _ = entry;
        // TODO: Integrate with V8 callback system
    }
}

// === Helper Functions ===

/// Check if mutation is allowed for this header name
fn canMutate(internal: *const InternalState, name: []const u8) bool {
    return switch (internal.guard) {
        .immutable => false,
        .request => !validation.isForbiddenRequestHeader(name, ""),
        .request_no_cors => !validation.isForbiddenRequestHeader(name, "") and
            validation.isNoCORSSafelistedRequestHeaderName(name),
        .response => !validation.isForbiddenResponseHeaderName(name),
        .none => true,
    };
}
