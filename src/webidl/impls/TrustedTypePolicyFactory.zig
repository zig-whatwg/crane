//! Implementation for TrustedTypePolicyFactory interface
//!
//! W3C Trusted Types Spec: https://w3c.github.io/trusted-types/dist/spec/
//!
//! TrustedTypePolicyFactory creates TrustedTypePolicy instances and provides
//! type checking utilities. Exposed as `window.trustedTypes` or `self.trustedTypes`.

const std = @import("std");
const runtime = @import("runtime");
const v8 = @import("v8");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const trusted_types = @import("trusted_types");
const TrustedTypePolicyFactory = interfaces.TrustedTypePolicyFactory;

pub const State = TrustedTypePolicyFactory.State;

pub const ImplError = error{
    NotImplemented,
    TypeError,
    OutOfMemory,
};

/// Internal state for TrustedTypePolicyFactory implementation
/// Stores the underlying trusted_types.TrustedTypePolicyFactory
pub const InternalState = struct {
    /// The underlying TrustedTypePolicyFactory from the trusted_types module
    inner: ?*trusted_types.TrustedTypePolicyFactory = null,

    pub fn deinit(self: *InternalState) void {
        if (self.inner) |factory| {
            factory.deinit();
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

    // Create the underlying factory
    const factory = try trusted_types.TrustedTypePolicyFactory.init(allocator);
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        internal.inner = factory;
    }

    return instance;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    // Clean up the underlying factory
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        internal.deinit();
    }
    // NOTE: Do NOT call runtime.Instance.deinit() - GC layer handles slab freeing
}

/// Getter for emptyHTML
/// Per spec: "readonly attribute TrustedHTML emptyHTML"
pub fn get_emptyHTML(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    // TODO: Return a TrustedHTML instance wrapping the empty HTML
    // This requires access to the TrustedHTML interface's vtable
    return error.NotImplemented;
}

/// Getter for emptyScript
/// Per spec: "readonly attribute TrustedScript emptyScript"
pub fn get_emptyScript(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    // TODO: Return a TrustedScript instance wrapping the empty script
    return error.NotImplemented;
}

/// Getter for defaultPolicy
/// Per spec: "readonly attribute TrustedTypePolicy? defaultPolicy"
pub fn get_defaultPolicy(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return null;
    const factory = internal.inner orelse return null;

    // Check if default policy exists
    _ = factory.getDefaultPolicy() orelse return null;

    // TODO: Return a TrustedTypePolicy instance wrapping the default policy
    // This requires access to the TrustedTypePolicy interface's vtable
    return error.NotImplemented;
}

/// Operation: createPolicy
/// Per spec: "TrustedTypePolicy createPolicy(DOMString policyName, optional TrustedTypePolicyOptions)"
pub fn call_createPolicy(instance: *runtime.Instance, policyName: runtime.DOMString, policyOptions: webidl.Opt(dictionaries.TrustedTypePolicyOptions)) anyerror!*runtime.Instance {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.NotImplemented;
    const factory = internal.inner orelse return error.NotImplemented;

    // Convert WebIDL TrustedTypePolicyOptions to trusted_types options
    // TODO: Handle callback conversion from JS to Zig
    _ = policyOptions;
    const options = trusted_types.TrustedTypePolicyOptions{};

    _ = factory.createPolicy(policyName.asSlice(), options) catch |err| switch (err) {
        trusted_types.FactoryError.TypeError => return error.TypeError,
        trusted_types.FactoryError.OutOfMemory => return error.OutOfMemory,
    };

    // TODO: Wrap the policy in a runtime.Instance
    return error.NotImplemented;
}

/// Operation: isHTML
/// Per spec: "boolean isHTML(any value)"
pub fn call_isHTML(instance: *runtime.Instance, value: runtime.JSValue) anyerror!bool {
    _ = instance;
    // Check if value is a TrustedHTML instance
    // In JS integration, this would check the internal slot
    // For now, basic type check
    _ = value;
    return false;
}

/// Operation: isScript
/// Per spec: "boolean isScript(any value)"
pub fn call_isScript(instance: *runtime.Instance, value: runtime.JSValue) anyerror!bool {
    _ = instance;
    _ = value;
    return false;
}

/// Operation: isScriptURL
/// Per spec: "boolean isScriptURL(any value)"
pub fn call_isScriptURL(instance: *runtime.Instance, value: runtime.JSValue) anyerror!bool {
    _ = instance;
    _ = value;
    return false;
}

/// Operation: getPropertyType
/// Per spec: "DOMString? getPropertyType(DOMString tagName, DOMString property, optional DOMString? elementNs)"
pub fn call_getPropertyType(instance: *runtime.Instance, tagName: runtime.DOMString, property: runtime.DOMString, elementNs: webidl.Opt(?runtime.DOMString)) anyerror!?runtime.DOMString {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return null;
    const factory = internal.inner orelse return null;

    // Extract namespace from optional
    const ns: ?[]const u8 = if (elementNs.wasPassed()) blk: {
        const opt_ns = elementNs.getValue();
        break :blk if (opt_ns) |s| s.asSlice() else null;
    } else null;

    if (factory.getPropertyType(tagName.asSlice(), property.asSlice(), ns)) |result| {
        return runtime.DOMString.initInterned(result);
    }
    return null;
}

/// Operation: getAttributeType
/// Per spec: "DOMString? getAttributeType(DOMString tagName, DOMString attribute, optional DOMString? elementNs, optional DOMString? attrNs)"
pub fn call_getAttributeType(instance: *runtime.Instance, tagName: runtime.DOMString, attribute: runtime.DOMString, elementNs: webidl.Opt(?runtime.DOMString), attrNs: webidl.Opt(?runtime.DOMString)) anyerror!?runtime.DOMString {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return null;
    const factory = internal.inner orelse return null;

    const elem_ns: ?[]const u8 = if (elementNs.wasPassed()) blk: {
        const opt_ns = elementNs.getValue();
        break :blk if (opt_ns) |s| s.asSlice() else null;
    } else null;
    const attr_ns: ?[]const u8 = if (attrNs.wasPassed()) blk: {
        const opt_ns = attrNs.getValue();
        break :blk if (opt_ns) |s| s.asSlice() else null;
    } else null;

    if (factory.getAttributeType(tagName.asSlice(), attribute.asSlice(), elem_ns, attr_ns)) |result| {
        return runtime.DOMString.initInterned(result);
    }
    return null;
}

/// Get the underlying factory directly
pub fn getFactory(instance: *runtime.Instance) ?*trusted_types.TrustedTypePolicyFactory {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return null;
    return internal.inner;
}
