//! Implementation for SVGAngle interface
//!
//! This file is AUTO-GENERATED on first creation.
//! Add your custom implementation here.

const std = @import("std");
const runtime = @import("runtime");
const SVGAngle = @import("interfaces").SVGAngle;

pub const State = SVGAngle.State;

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

/// Getter for unitType
pub fn get_unitType(instance: *runtime.Instance) ImplError!u16 {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for value
pub fn get_value(instance: *runtime.Instance) ImplError!f32 {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for valueInSpecifiedUnits
pub fn get_valueInSpecifiedUnits(instance: *runtime.Instance) ImplError!f32 {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for valueAsString
pub fn get_valueAsString(instance: *runtime.Instance) ImplError!runtime.DOMString {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Setter for value
pub fn set_value(instance: *runtime.Instance, value: f32) ImplError!void {
    _ = instance;
    _ = value;
    // TODO: Implement setter
    return error.NotImplemented;
}

/// Setter for valueInSpecifiedUnits
pub fn set_valueInSpecifiedUnits(instance: *runtime.Instance, value: f32) ImplError!void {
    _ = instance;
    _ = value;
    // TODO: Implement setter
    return error.NotImplemented;
}

/// Setter for valueAsString
pub fn set_valueAsString(instance: *runtime.Instance, value: runtime.DOMString) ImplError!void {
    _ = instance;
    _ = value;
    // TODO: Implement setter
    return error.NotImplemented;
}

/// Operation: newValueSpecifiedUnits
pub fn call_newValueSpecifiedUnits(instance: *runtime.Instance, unitType: u16, valueInSpecifiedUnits: f32) ImplError!void {
    _ = instance;
    _ = unitType;
    _ = valueInSpecifiedUnits;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: convertToSpecifiedUnits
pub fn call_convertToSpecifiedUnits(instance: *runtime.Instance, unitType: u16) ImplError!void {
    _ = instance;
    _ = unitType;
    // TODO: Implement operation
    return error.NotImplemented;
}

