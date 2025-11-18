//! Implementation for FontFaceSet interface
//!
//! This file is AUTO-GENERATED on first creation.
//! Add your custom implementation here.

const std = @import("std");
const runtime = @import("runtime");
const FontFaceSet = @import("interfaces").FontFaceSet;

pub const State = FontFaceSet.State;

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

/// Constructor implementation
pub fn constructor(instance: *runtime.Instance) !void {
    _ = instance;
    // TODO: Implement constructor logic
}

/// Getter for onloading
pub fn get_onloading(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for onloadingdone
pub fn get_onloadingdone(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for onloadingerror
pub fn get_onloadingerror(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for ready
pub fn get_ready(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for status
pub fn get_status(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Setter for onloading
pub fn set_onloading(instance: *runtime.Instance, value: anyopaque) ImplError!void {
    _ = instance;
    _ = value;
    // TODO: Implement setter
    return error.NotImplemented;
}

/// Setter for onloadingdone
pub fn set_onloadingdone(instance: *runtime.Instance, value: anyopaque) ImplError!void {
    _ = instance;
    _ = value;
    // TODO: Implement setter
    return error.NotImplemented;
}

/// Setter for onloadingerror
pub fn set_onloadingerror(instance: *runtime.Instance, value: anyopaque) ImplError!void {
    _ = instance;
    _ = value;
    // TODO: Implement setter
    return error.NotImplemented;
}

/// Operation: addEventListener
pub fn call_addEventListener(instance: *runtime.Instance, type: runtime.DOMString, callback: anyopaque, options: anyopaque) ImplError!void {
    _ = instance;
    _ = type;
    _ = callback;
    _ = options;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: removeEventListener
pub fn call_removeEventListener(instance: *runtime.Instance, type: runtime.DOMString, callback: anyopaque, options: anyopaque) ImplError!void {
    _ = instance;
    _ = type;
    _ = callback;
    _ = options;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: dispatchEvent
pub fn call_dispatchEvent(instance: *runtime.Instance, event: anyopaque) ImplError!bool {
    _ = instance;
    _ = event;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: when
pub fn call_when(instance: *runtime.Instance, type: runtime.DOMString, options: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = type;
    _ = options;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: add
pub fn call_add(instance: *runtime.Instance, font: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = font;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: delete
pub fn call_delete(instance: *runtime.Instance, font: anyopaque) ImplError!bool {
    _ = instance;
    _ = font;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: clear
pub fn call_clear(instance: *runtime.Instance) ImplError!void {
    _ = instance;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: load
pub fn call_load(instance: *runtime.Instance, font: anyopaque, text: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = font;
    _ = text;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: check
pub fn call_check(instance: *runtime.Instance, font: anyopaque, text: anyopaque) ImplError!bool {
    _ = instance;
    _ = font;
    _ = text;
    // TODO: Implement operation
    return error.NotImplemented;
}

