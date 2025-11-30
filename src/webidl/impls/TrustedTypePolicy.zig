//! Implementation for TrustedTypePolicy interface
//!
//! W3C Trusted Types Spec: https://w3c.github.io/trusted-types/dist/spec/
//!
//! TrustedTypePolicy creates Trusted Types using user-defined callback functions.
//! It is created through TrustedTypePolicyFactory.createPolicy().

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const trusted_types = @import("trusted_types");
const TrustedTypePolicy = interfaces.TrustedTypePolicy;

pub const State = TrustedTypePolicy.State;

pub const ImplError = error{
    NotImplemented,
    TypeError,
    OutOfMemory,
};

/// Internal state for TrustedTypePolicy implementation
/// Stores the underlying trusted_types.TrustedTypePolicy reference
pub const InternalState = struct {
    /// The underlying TrustedTypePolicy from the trusted_types module
    /// Note: The factory owns the policy, we just hold a reference
    inner: ?*trusted_types.TrustedTypePolicy = null,

    pub fn deinit(self: *InternalState) void {
        // Note: We don't own the policy - the factory does
        _ = self;
    }
};

/// Initialize instance (creates the instance)
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    const instance = try runtime.Instance.init(allocator, StateType, vtable, ctx);
    return instance;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    // Note: We don't own the policy - the factory does
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        internal.deinit();
    }
    runtime.Instance.deinit(instance);
}

/// Getter for name
/// Per spec: "readonly attribute DOMString name"
pub fn get_name(instance: *runtime.Instance) anyerror!runtime.DOMString {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return runtime.DOMString.initEmpty();
    if (internal.inner) |inner| {
        return runtime.DOMString.initInterned(inner.name);
    }
    return runtime.DOMString.initEmpty();
}

/// Operation: createHTML
/// Per spec: "TrustedHTML createHTML(DOMString input, any... arguments)"
pub fn call_createHTML(instance: *runtime.Instance, input: runtime.DOMString, arguments: []const *const anyopaque) anyerror!*runtime.Instance {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.NotImplemented;
    const policy = internal.inner orelse return error.NotImplemented;

    // Create the TrustedHTML via the policy
    // Note: arguments are passed as opaque context for now
    // Full variadic argument handling requires JS runtime integration
    const context: ?*anyopaque = if (arguments.len > 0) @constCast(arguments[0]) else null;

    // Convert DOMString to slice for the policy
    const input_slice = input.asSlice();

    const html = policy.createHTML(input_slice, context) catch |err| switch (err) {
        trusted_types.PolicyError.TypeError => return error.TypeError,
        trusted_types.PolicyError.OutOfMemory => return error.OutOfMemory,
        else => return error.NotImplemented,
    };

    // TODO: Wrap the TrustedHTML in a runtime.Instance
    // This requires access to the TrustedHTML interface's vtable and context
    // For now, return the error as this needs JS runtime integration
    _ = html;
    return error.NotImplemented;
}

/// Operation: createScript
/// Per spec: "TrustedScript createScript(DOMString input, any... arguments)"
pub fn call_createScript(instance: *runtime.Instance, input: runtime.DOMString, arguments: []const *const anyopaque) anyerror!*runtime.Instance {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.NotImplemented;
    const policy = internal.inner orelse return error.NotImplemented;

    const context: ?*anyopaque = if (arguments.len > 0) @constCast(arguments[0]) else null;

    // Convert DOMString to slice for the policy
    const input_slice = input.asSlice();

    const script = policy.createScript(input_slice, context) catch |err| switch (err) {
        trusted_types.PolicyError.TypeError => return error.TypeError,
        trusted_types.PolicyError.OutOfMemory => return error.OutOfMemory,
        else => return error.NotImplemented,
    };

    _ = script;
    return error.NotImplemented;
}

/// Operation: createScriptURL
/// Per spec: "TrustedScriptURL createScriptURL(DOMString input, any... arguments)"
pub fn call_createScriptURL(instance: *runtime.Instance, input: runtime.DOMString, arguments: []const *const anyopaque) anyerror!*runtime.Instance {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.NotImplemented;
    const policy = internal.inner orelse return error.NotImplemented;

    const context: ?*anyopaque = if (arguments.len > 0) @constCast(arguments[0]) else null;

    // Convert DOMString to slice for the policy
    const input_slice = input.asSlice();

    const url = policy.createScriptURL(input_slice, context) catch |err| switch (err) {
        trusted_types.PolicyError.TypeError => return error.TypeError,
        trusted_types.PolicyError.OutOfMemory => return error.OutOfMemory,
        else => return error.NotImplemented,
    };

    _ = url;
    return error.NotImplemented;
}

/// Get the underlying policy directly
pub fn getPolicy(instance: *runtime.Instance) ?*trusted_types.TrustedTypePolicy {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return null;
    return internal.inner;
}
