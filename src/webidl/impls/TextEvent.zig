//! Implementation for TextEvent interface
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
const TextEvent = interfaces.TextEvent;

pub const State = TextEvent.State;

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

/// Getter for data
pub fn get_data(instance: *runtime.Instance) ImplError!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: initTextEvent
pub fn call_initTextEvent(instance: *runtime.Instance, @"type": runtime.DOMString, bubbles: bool, cancelable: bool, view: *runtime.Instance, data: runtime.DOMString) ImplError!void {
    _ = instance;
    _ = @"type";
    _ = bubbles;
    _ = cancelable;
    _ = view;
    _ = data;
    return error.NotImplemented;
}

