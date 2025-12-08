//! Implementation for TrustedScriptURL interface
//!
//! W3C Trusted Types Spec: https://w3c.github.io/trusted-types/dist/spec/
//!
//! TrustedScriptURL represents a URL string that is safe to use as a script source.
//! It is created through TrustedTypePolicy.createScriptURL() and verified via
//! TrustedTypePolicyFactory.isScriptURL().

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const trusted_types = @import("trusted_types");
const TrustedScriptURL = interfaces.TrustedScriptURL;

pub const State = TrustedScriptURL.State;

pub const ImplError = error{
    NotImplemented,
    OutOfMemory,
};

/// Internal state for TrustedScriptURL implementation
/// Stores the underlying trusted_types.TrustedScriptURL value
pub const InternalState = struct {
    /// The underlying TrustedScriptURL value from the trusted_types module
    inner: ?trusted_types.TrustedScriptURL = null,

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
    // Clean up the underlying TrustedScriptURL if present
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        internal.deinit();
    }
    // NOTE: Do NOT call runtime.Instance.deinit() - GC layer handles slab freeing
}

/// Internal: stringifier implementation
///
/// Returns the URL string representation of the TrustedScriptURL value.
/// NOT a WebIDL operation - stringifiers are handled differently.
/// Per spec: "The stringifier must return the value of the object's [[Data]] internal slot."
pub fn stringify(instance: *runtime.Instance) anyerror!runtime.USVString {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return "";
    if (internal.inner) |inner| {
        return inner.toString();
    }
    return "";
}

/// Operation: toJSON
/// Per spec: "The toJSON() method steps are to return the value of the object's [[Data]] internal slot."
/// Note: Per spec, returns USVString (Unicode scalar values).
pub fn call_toJSON(instance: *runtime.Instance) anyerror!runtime.USVString {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return "";
    if (internal.inner) |inner| {
        return inner.toJSON();
    }
    return "";
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

/// Check if this instance contains a valid TrustedScriptURL value
pub fn isValid(instance: *runtime.Instance) bool {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return false;
    return internal.inner != null;
}
