//! Implementation for TrustedTypePolicyFactory interface
//!
//! This file is AUTO-GENERATED on first creation.
//! Add your custom implementation here.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const TrustedTypePolicyFactory = interfaces.TrustedTypePolicyFactory;

pub const State = TrustedTypePolicyFactory.State;

pub const ImplError = error{
    NotImplemented,
};

/// Initialize instance (creates the instance)
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    const instance = try runtime.Instance.init(allocator, StateType, vtable, ctx);
    // TODO: Initialize your instance state here if needed
    return instance;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    // TODO: Clean up your instance resources here
    runtime.Instance.deinit(instance);
}

/// Getter for emptyHTML
pub fn get_emptyHTML(instance: *runtime.Instance) ImplError!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for emptyScript
pub fn get_emptyScript(instance: *runtime.Instance) ImplError!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for defaultPolicy
pub fn get_defaultPolicy(instance: *runtime.Instance) ImplError!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: createPolicy
pub fn call_createPolicy(instance: *runtime.Instance, policyName: runtime.DOMString, policyOptions: dictionaries.TrustedTypePolicyOptions) ImplError!*runtime.Instance {
    _ = instance;
    _ = policyName;
    _ = policyOptions;
    return error.NotImplemented;
}

/// Operation: isScript
pub fn call_isScript(instance: *runtime.Instance, value: *const anyopaque) ImplError!bool {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Operation: isScriptURL
pub fn call_isScriptURL(instance: *runtime.Instance, value: *const anyopaque) ImplError!bool {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Operation: getPropertyType
pub fn call_getPropertyType(instance: *runtime.Instance, tagName: runtime.DOMString, property: runtime.DOMString, elementNs: runtime.DOMString) ImplError!runtime.DOMString {
    _ = instance;
    _ = tagName;
    _ = property;
    _ = elementNs;
    return error.NotImplemented;
}

/// Operation: isHTML
pub fn call_isHTML(instance: *runtime.Instance, value: *const anyopaque) ImplError!bool {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Operation: getAttributeType
pub fn call_getAttributeType(instance: *runtime.Instance, tagName: runtime.DOMString, attribute: runtime.DOMString, elementNs: runtime.DOMString, attrNs: runtime.DOMString) ImplError!runtime.DOMString {
    _ = instance;
    _ = tagName;
    _ = attribute;
    _ = elementNs;
    _ = attrNs;
    return error.NotImplemented;
}

