//! Implementation for HTMLOptionsCollection interface
//!
//! This file is AUTO-GENERATED on first creation.
//! Add your custom implementation here.

const std = @import("std");
const runtime = @import("runtime");
const HTMLOptionsCollection = @import("interfaces").HTMLOptionsCollection;

pub const State = HTMLOptionsCollection.State;

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

/// Getter for length
pub fn get_length(instance: *runtime.Instance) ImplError!u32 {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for selectedIndex
pub fn get_selectedIndex(instance: *runtime.Instance) ImplError!i32 {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Setter for length
pub fn set_length(instance: *runtime.Instance, value: u32) ImplError!void {
    _ = instance;
    _ = value;
    // TODO: Implement setter
    return error.NotImplemented;
}

/// Setter for selectedIndex
pub fn set_selectedIndex(instance: *runtime.Instance, value: i32) ImplError!void {
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

/// Operation: namedItem
pub fn call_namedItem(instance: *runtime.Instance, name: runtime.DOMString) ImplError!anyopaque {
    _ = instance;
    _ = name;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: unnamed
pub fn call_unnamed(instance: *runtime.Instance, index: u32, option: anyopaque) ImplError!void {
    _ = instance;
    _ = index;
    _ = option;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: add
pub fn call_add(instance: *runtime.Instance, element: anyopaque, before: anyopaque) ImplError!void {
    _ = instance;
    _ = element;
    _ = before;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: remove
pub fn call_remove(instance: *runtime.Instance, index: i32) ImplError!void {
    _ = instance;
    _ = index;
    // TODO: Implement operation
    return error.NotImplemented;
}

