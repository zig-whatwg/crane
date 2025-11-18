//! Implementation for SVGPointList interface
//!
//! This file is AUTO-GENERATED on first creation.
//! Add your custom implementation here.

const std = @import("std");
const runtime = @import("runtime");
const SVGPointList = @import("interfaces").SVGPointList;

pub const State = SVGPointList.State;

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

/// Getter for length
pub fn get_length(instance: *runtime.Instance) ImplError!u32 {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for numberOfItems
pub fn get_numberOfItems(instance: *runtime.Instance) ImplError!u32 {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Operation: clear
pub fn call_clear(instance: *runtime.Instance) ImplError!void {
    _ = instance;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: initialize
pub fn call_initialize(instance: *runtime.Instance, newItem: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = newItem;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: getItem
pub fn call_getItem(instance: *runtime.Instance, index: u32) ImplError!anyopaque {
    _ = instance;
    _ = index;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: insertItemBefore
pub fn call_insertItemBefore(instance: *runtime.Instance, newItem: anyopaque, index: u32) ImplError!anyopaque {
    _ = instance;
    _ = newItem;
    _ = index;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: replaceItem
pub fn call_replaceItem(instance: *runtime.Instance, newItem: anyopaque, index: u32) ImplError!anyopaque {
    _ = instance;
    _ = newItem;
    _ = index;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: removeItem
pub fn call_removeItem(instance: *runtime.Instance, index: u32) ImplError!anyopaque {
    _ = instance;
    _ = index;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: appendItem
pub fn call_appendItem(instance: *runtime.Instance, newItem: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = newItem;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: unnamed
pub fn call_unnamed(instance: *runtime.Instance, index: u32, newItem: anyopaque) ImplError!void {
    _ = instance;
    _ = index;
    _ = newItem;
    // TODO: Implement operation
    return error.NotImplemented;
}

