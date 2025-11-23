//! Implementation for CSSStyleDeclaration interface
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
const CSSStyleDeclaration = interfaces.CSSStyleDeclaration;

pub const State = CSSStyleDeclaration.State;

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

/// Getter for cssText
pub fn get_cssText(instance: *runtime.Instance) ImplError!typedefs.CSSOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for length
pub fn get_length(instance: *runtime.Instance) ImplError!u32 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for parentRule
pub fn get_parentRule(instance: *runtime.Instance) ImplError!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Setter for cssText
pub fn set_cssText(instance: *runtime.Instance, value: typedefs.CSSOMString) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Operation: item
pub fn call_item(instance: *runtime.Instance, index: u32) ImplError!typedefs.CSSOMString {
    _ = instance;
    _ = index;
    return error.NotImplemented;
}

/// Operation: removeProperty
pub fn call_removeProperty(instance: *runtime.Instance, property: typedefs.CSSOMString) ImplError!typedefs.CSSOMString {
    _ = instance;
    _ = property;
    return error.NotImplemented;
}

/// Operation: getPropertyCSSValue
pub fn call_getPropertyCSSValue(instance: *runtime.Instance, propertyName: runtime.DOMString) ImplError!*runtime.Instance {
    _ = instance;
    _ = propertyName;
    return error.NotImplemented;
}

/// Operation: getPropertyPriority
pub fn call_getPropertyPriority(instance: *runtime.Instance, property: typedefs.CSSOMString) ImplError!typedefs.CSSOMString {
    _ = instance;
    _ = property;
    return error.NotImplemented;
}

/// Operation: setProperty
pub fn call_setProperty(instance: *runtime.Instance, property: typedefs.CSSOMString, value: typedefs.CSSOMString, priority: typedefs.CSSOMString) ImplError!void {
    _ = instance;
    _ = property;
    _ = value;
    _ = priority;
    return error.NotImplemented;
}

/// Operation: getPropertyValue
pub fn call_getPropertyValue(instance: *runtime.Instance, property: typedefs.CSSOMString) ImplError!typedefs.CSSOMString {
    _ = instance;
    _ = property;
    return error.NotImplemented;
}

