//! Implementation for SVGNumberList interface
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
const SVGNumberList = interfaces.SVGNumberList;

pub const State = SVGNumberList.State;

pub const ImplError = error{
    NotImplemented,
};

/// Internal state for this implementation
/// Can be used to store browser-specific data structures
pub const InternalState = struct {};

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

/// Getter for length
pub fn get_length(instance: *runtime.Instance) ImplError!u32 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for numberOfItems
pub fn get_numberOfItems(instance: *runtime.Instance) ImplError!u32 {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: removeItem
pub fn call_removeItem(instance: *runtime.Instance, index: u32) ImplError!interfaces.SVGNumber {
    _ = instance;
    _ = index;
    return error.NotImplemented;
}

/// Operation: insertItemBefore
pub fn call_insertItemBefore(instance: *runtime.Instance, newItem: interfaces.SVGNumber, index: u32) ImplError!interfaces.SVGNumber {
    _ = instance;
    _ = newItem;
    _ = index;
    return error.NotImplemented;
}

/// Operation: getItem
pub fn call_getItem(instance: *runtime.Instance, index: u32) ImplError!interfaces.SVGNumber {
    _ = instance;
    _ = index;
    return error.NotImplemented;
}

/// Operation: replaceItem
pub fn call_replaceItem(instance: *runtime.Instance, newItem: interfaces.SVGNumber, index: u32) ImplError!interfaces.SVGNumber {
    _ = instance;
    _ = newItem;
    _ = index;
    return error.NotImplemented;
}

/// Operation: clear
pub fn call_clear(instance: *runtime.Instance) ImplError!void {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: initialize
pub fn call_initialize(instance: *runtime.Instance, newItem: interfaces.SVGNumber) ImplError!interfaces.SVGNumber {
    _ = instance;
    _ = newItem;
    return error.NotImplemented;
}

/// Operation: appendItem
pub fn call_appendItem(instance: *runtime.Instance, newItem: interfaces.SVGNumber) ImplError!interfaces.SVGNumber {
    _ = instance;
    _ = newItem;
    return error.NotImplemented;
}

