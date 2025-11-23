//! Implementation for FontFaceSet interface
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
const FontFaceSet = interfaces.FontFaceSet;

pub const State = FontFaceSet.State;

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

/// Getter for onloading
pub fn get_onloading(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onloadingdone
pub fn get_onloadingdone(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onloadingerror
pub fn get_onloadingerror(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for ready
pub fn get_ready(instance: *runtime.Instance) ImplError!*const anyopaque {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for status
pub fn get_status(instance: *runtime.Instance) ImplError!enums.FontFaceSetLoadStatus {
    _ = instance;
    return error.NotImplemented;
}

/// Setter for onloading
pub fn set_onloading(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onloadingdone
pub fn set_onloadingdone(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onloadingerror
pub fn set_onloadingerror(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Operation: delete
pub fn call_delete(instance: *runtime.Instance, font: *runtime.Instance) ImplError!bool {
    _ = instance;
    _ = font;
    return error.NotImplemented;
}

/// Operation: add
pub fn call_add(instance: *runtime.Instance, font: *runtime.Instance) ImplError!*runtime.Instance {
    _ = instance;
    _ = font;
    return error.NotImplemented;
}

/// Operation: clear
pub fn call_clear(instance: *runtime.Instance) ImplError!void {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: load
pub fn call_load(instance: *runtime.Instance, font: typedefs.CSSOMString, text: typedefs.CSSOMString) ImplError!*const anyopaque {
    _ = instance;
    _ = font;
    _ = text;
    return error.NotImplemented;
}

/// Operation: check
pub fn call_check(instance: *runtime.Instance, font: typedefs.CSSOMString, text: typedefs.CSSOMString) ImplError!bool {
    _ = instance;
    _ = font;
    _ = text;
    return error.NotImplemented;
}

