//! Implementation for CharacterData interface
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
const CharacterData = interfaces.CharacterData;

pub const State = CharacterData.State;

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

/// Getter for data
pub fn get_data(instance: *runtime.Instance) ImplError!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for length
pub fn get_length(instance: *runtime.Instance) ImplError!u32 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for previousElementSibling
pub fn get_previousElementSibling(instance: *runtime.Instance) ImplError!interfaces.Element {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for nextElementSibling
pub fn get_nextElementSibling(instance: *runtime.Instance) ImplError!interfaces.Element {
    _ = instance;
    return error.NotImplemented;
}

/// Setter for data
pub fn set_data(instance: *runtime.Instance, value: runtime.DOMString) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Operation: insertData
pub fn call_insertData(instance: *runtime.Instance, offset: u32, data: runtime.DOMString) ImplError!void {
    _ = instance;
    _ = offset;
    _ = data;
    return error.NotImplemented;
}

/// Operation: substringData
pub fn call_substringData(instance: *runtime.Instance, offset: u32, count: u32) ImplError!runtime.DOMString {
    _ = instance;
    _ = offset;
    _ = count;
    return error.NotImplemented;
}

/// Operation: replaceWith
pub fn call_replaceWith(instance: *runtime.Instance, nodes: *const anyopaque) ImplError!void {
    _ = instance;
    _ = nodes;
    return error.NotImplemented;
}

/// Operation: before
pub fn call_before(instance: *runtime.Instance, nodes: *const anyopaque) ImplError!void {
    _ = instance;
    _ = nodes;
    return error.NotImplemented;
}

/// Operation: after
pub fn call_after(instance: *runtime.Instance, nodes: *const anyopaque) ImplError!void {
    _ = instance;
    _ = nodes;
    return error.NotImplemented;
}

/// Operation: appendData
pub fn call_appendData(instance: *runtime.Instance, data: runtime.DOMString) ImplError!void {
    _ = instance;
    _ = data;
    return error.NotImplemented;
}

/// Operation: deleteData
pub fn call_deleteData(instance: *runtime.Instance, offset: u32, count: u32) ImplError!void {
    _ = instance;
    _ = offset;
    _ = count;
    return error.NotImplemented;
}

/// Operation: replaceData
pub fn call_replaceData(instance: *runtime.Instance, offset: u32, count: u32, data: runtime.DOMString) ImplError!void {
    _ = instance;
    _ = offset;
    _ = count;
    _ = data;
    return error.NotImplemented;
}

/// Operation: remove
pub fn call_remove(instance: *runtime.Instance) ImplError!void {
    _ = instance;
    return error.NotImplemented;
}

