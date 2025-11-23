//! Implementation for VirtualKeyboard interface
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
const VirtualKeyboard = interfaces.VirtualKeyboard;

pub const State = VirtualKeyboard.State;

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

/// Getter for boundingRect
pub fn get_boundingRect(instance: *runtime.Instance) ImplError!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for overlaysContent
pub fn get_overlaysContent(instance: *runtime.Instance) ImplError!bool {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for ongeometrychange
pub fn get_ongeometrychange(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Setter for overlaysContent
pub fn set_overlaysContent(instance: *runtime.Instance, value: bool) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for ongeometrychange
pub fn set_ongeometrychange(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Operation: hide
pub fn call_hide(instance: *runtime.Instance) ImplError!void {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: show
pub fn call_show(instance: *runtime.Instance) ImplError!void {
    _ = instance;
    return error.NotImplemented;
}

