//! Implementation for TrustedHTML interface
//!
//! W3C Trusted Types Spec: https://w3c.github.io/trusted-types/dist/spec/
//!
//! TrustedHTML represents a string that is safe to use in HTML contexts.
//! It is created through TrustedTypePolicy.createHTML() and verified via
//! TrustedTypePolicyFactory.isHTML().

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const trusted_types = @import("trusted_types");
const TrustedHTML = interfaces.TrustedHTML;

pub const State = TrustedHTML.State;

pub const ImplError = error{
    NotImplemented,
    OutOfMemory,
};

/// Internal state for TrustedHTML implementation
/// Stores the underlying trusted_types.TrustedHTML value
pub const InternalState = struct {
    /// The underlying TrustedHTML value from the trusted_types module
    inner: ?trusted_types.TrustedHTML = null,

    pub fn deinit(self: *InternalState) void {
        if (self.inner) |*inner| {
            inner.deinit();
        }
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
    // InternalState is zero-initialized by default
    return instance;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    // Clean up the underlying TrustedHTML if present
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        internal.deinit();
    }
    runtime.Instance.deinit(instance);
}

/// Stringifier - returns the string representation
/// Per spec: "The stringifier must return the value of the object's [[Data]] internal slot."
pub fn call_toString(instance: *runtime.Instance) anyerror!runtime.DOMString {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return runtime.DOMString.initEmpty();
    if (internal.inner) |inner| {
        return runtime.DOMString.initInterned(inner.toString());
    }
    return runtime.DOMString.initEmpty();
}

/// Operation: toJSON
/// Per spec: "The toJSON() method steps are to return the value of the object's [[Data]] internal slot."
pub fn call_toJSON(instance: *runtime.Instance) anyerror!runtime.DOMString {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return runtime.DOMString.initEmpty();
    if (internal.inner) |inner| {
        return runtime.DOMString.initInterned(inner.toJSON());
    }
    return runtime.DOMString.initEmpty();
}

/// Get the underlying data value directly
pub fn getData(instance: *runtime.Instance) ?[]const u8 {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return null;
    if (internal.inner) |inner| {
        return inner.data;
    }
    return null;
}

/// Check if this instance contains a valid TrustedHTML value
pub fn isValid(instance: *runtime.Instance) bool {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return false;
    return internal.inner != null;
}
