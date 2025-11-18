//! Implementation for TrustedTypePolicyFactory interface
//!
//! This file is AUTO-GENERATED on first creation.
//! Add your custom implementation here.

const std = @import("std");
const runtime = @import("runtime");
const TrustedTypePolicyFactory = @import("interfaces").TrustedTypePolicyFactory;

pub const State = TrustedTypePolicyFactory.State;

pub const ImplError = error{
    NotImplemented,
};

/// Initialize instance
pub fn init(instance: *runtime.Instance) void {
    _ = instance;
    // TODO: Initialize your instance state here
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    _ = instance;
    // TODO: Clean up your instance resources here
}

/// Getter for emptyHTML
pub fn get_emptyHTML(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for emptyScript
pub fn get_emptyScript(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for defaultPolicy
pub fn get_defaultPolicy(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Operation: createPolicy
pub fn call_createPolicy(instance: *runtime.Instance, policyName: runtime.DOMString, policyOptions: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = policyName;
    _ = policyOptions;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: isHTML
pub fn call_isHTML(instance: *runtime.Instance, value: anyopaque) ImplError!bool {
    _ = instance;
    _ = value;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: isScript
pub fn call_isScript(instance: *runtime.Instance, value: anyopaque) ImplError!bool {
    _ = instance;
    _ = value;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: isScriptURL
pub fn call_isScriptURL(instance: *runtime.Instance, value: anyopaque) ImplError!bool {
    _ = instance;
    _ = value;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: getAttributeType
pub fn call_getAttributeType(instance: *runtime.Instance, tagName: runtime.DOMString, attribute: runtime.DOMString, elementNs: anyopaque, attrNs: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = tagName;
    _ = attribute;
    _ = elementNs;
    _ = attrNs;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: getPropertyType
pub fn call_getPropertyType(instance: *runtime.Instance, tagName: runtime.DOMString, property: runtime.DOMString, elementNs: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = tagName;
    _ = property;
    _ = elementNs;
    // TODO: Implement operation
    return error.NotImplemented;
}

