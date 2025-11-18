//! Implementation for CSSPrimitiveValue interface
//!
//! This file is AUTO-GENERATED on first creation.
//! Add your custom implementation here.

const std = @import("std");
const runtime = @import("runtime");
const CSSPrimitiveValue = @import("interfaces").CSSPrimitiveValue;

pub const State = CSSPrimitiveValue.State;

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
pub fn get_cssText(instance: *runtime.Instance) ImplError!runtime.DOMString {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for cssValueType
pub fn get_cssValueType(instance: *runtime.Instance) ImplError!u16 {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for primitiveType
pub fn get_primitiveType(instance: *runtime.Instance) ImplError!u16 {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Setter for cssText
pub fn set_cssText(instance: *runtime.Instance, value: runtime.DOMString) ImplError!void {
    _ = instance;
    _ = value;
    // TODO: Implement setter
    return error.NotImplemented;
}

/// Operation: setFloatValue
pub fn call_setFloatValue(instance: *runtime.Instance, unitType: u16, floatValue: f32) ImplError!void {
    _ = instance;
    _ = unitType;
    _ = floatValue;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: getFloatValue
pub fn call_getFloatValue(instance: *runtime.Instance, unitType: u16) ImplError!f32 {
    _ = instance;
    _ = unitType;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: setStringValue
pub fn call_setStringValue(instance: *runtime.Instance, stringType: u16, stringValue: runtime.DOMString) ImplError!void {
    _ = instance;
    _ = stringType;
    _ = stringValue;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: getStringValue
pub fn call_getStringValue(instance: *runtime.Instance) ImplError!runtime.DOMString {
    _ = instance;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: getCounterValue
pub fn call_getCounterValue(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: getRectValue
pub fn call_getRectValue(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: getRGBColorValue
pub fn call_getRGBColorValue(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement operation
    return error.NotImplemented;
}

