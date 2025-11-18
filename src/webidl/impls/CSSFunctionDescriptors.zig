//! Implementation for CSSFunctionDescriptors interface
//!
//! This file is AUTO-GENERATED on first creation.
//! Add your custom implementation here.

const std = @import("std");
const runtime = @import("runtime");
const CSSFunctionDescriptors = @import("interfaces").CSSFunctionDescriptors;

pub const State = CSSFunctionDescriptors.State;

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

/// Getter for cssText
pub fn get_cssText(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for length
pub fn get_length(instance: *runtime.Instance) ImplError!u32 {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for parentRule
pub fn get_parentRule(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for cssText
pub fn get_cssText(instance: *runtime.Instance) ImplError!runtime.DOMString {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for length
pub fn get_length(instance: *runtime.Instance) ImplError!u32 {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for parentRule
pub fn get_parentRule(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for result
pub fn get_result(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Setter for cssText
pub fn set_cssText(instance: *runtime.Instance, value: anyopaque) ImplError!void {
    _ = instance;
    _ = value;
    // TODO: Implement setter
    return error.NotImplemented;
}

/// Setter for cssText
pub fn set_cssText(instance: *runtime.Instance, value: runtime.DOMString) ImplError!void {
    _ = instance;
    _ = value;
    // TODO: Implement setter
    return error.NotImplemented;
}

/// Setter for result
pub fn set_result(instance: *runtime.Instance, value: anyopaque) ImplError!void {
    _ = instance;
    _ = value;
    // TODO: Implement setter
    return error.NotImplemented;
}

/// Operation: item
pub fn call_item(instance: *runtime.Instance, index: u32) ImplError!anyopaque {
    _ = instance;
    _ = index;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: getPropertyValue
pub fn call_getPropertyValue(instance: *runtime.Instance, property: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = property;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: getPropertyPriority
pub fn call_getPropertyPriority(instance: *runtime.Instance, property: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = property;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: setProperty
pub fn call_setProperty(instance: *runtime.Instance, property: anyopaque, value: anyopaque, priority: anyopaque) ImplError!void {
    _ = instance;
    _ = property;
    _ = value;
    _ = priority;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: removeProperty
pub fn call_removeProperty(instance: *runtime.Instance, property: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = property;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: getPropertyValue
pub fn call_getPropertyValue(instance: *runtime.Instance, propertyName: runtime.DOMString) ImplError!runtime.DOMString {
    _ = instance;
    _ = propertyName;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: getPropertyCSSValue
pub fn call_getPropertyCSSValue(instance: *runtime.Instance, propertyName: runtime.DOMString) ImplError!anyopaque {
    _ = instance;
    _ = propertyName;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: removeProperty
pub fn call_removeProperty(instance: *runtime.Instance, propertyName: runtime.DOMString) ImplError!runtime.DOMString {
    _ = instance;
    _ = propertyName;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: getPropertyPriority
pub fn call_getPropertyPriority(instance: *runtime.Instance, propertyName: runtime.DOMString) ImplError!runtime.DOMString {
    _ = instance;
    _ = propertyName;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: setProperty
pub fn call_setProperty(instance: *runtime.Instance, propertyName: runtime.DOMString, value: runtime.DOMString, priority: runtime.DOMString) ImplError!void {
    _ = instance;
    _ = propertyName;
    _ = value;
    _ = priority;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: item
pub fn call_item(instance: *runtime.Instance, index: u32) ImplError!runtime.DOMString {
    _ = instance;
    _ = index;
    // TODO: Implement operation
    return error.NotImplemented;
}

