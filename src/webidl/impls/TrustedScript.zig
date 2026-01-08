//! Implementation for TrustedScript interface
//!
//! W3C Trusted Types Spec: https://w3c.github.io/trusted-types/dist/spec/
//!
//! TrustedScript represents a string that is safe to use as script content.
//! It is created through TrustedTypePolicy.createScript() and verified via
//! TrustedTypePolicyFactory.isScript().

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const trusted_types = @import("trusted_types");
const TrustedScript = interfaces.TrustedScript;

pub const State = TrustedScript.State;

pub const ImplError = error{
    NotImplemented,
    OutOfMemory,
};

/// Internal state for TrustedScript implementation
/// Stores the underlying trusted_types.TrustedScript value
pub const InternalState = struct {
    /// The underlying TrustedScript value from the trusted_types module
    inner: ?trusted_types.TrustedScript = null,

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
    // Clean up the underlying TrustedScript if present
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        internal.deinit();
    }
    // NOTE: Do NOT call runtime.Instance.deinit() - GC layer handles slab freeing
}

/// Internal: stringifier implementation
///
/// Returns the string representation of the TrustedScript value.
/// NOT a WebIDL operation - stringifiers are handled differently.
/// Per spec: "The stringifier must return the value of the object's [[Data]] internal slot."
pub fn stringify(instance: *runtime.Instance) anyerror!runtime.DOMString {
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

/// Check if this instance contains a valid TrustedScript value
pub fn isValid(instance: *runtime.Instance) bool {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return false;
    return internal.inner != null;
}

/// Stringifier - serialize method for toString
pub fn serialize(instance: *runtime.Instance) anyerror!runtime.USVString {
    _ = instance;
    return "[object]";
}


pub fn call_stringifier(instance: *runtime.Instance) anyerror!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}