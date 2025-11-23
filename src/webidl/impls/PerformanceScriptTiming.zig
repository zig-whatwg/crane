//! Implementation for PerformanceScriptTiming interface
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
const PerformanceScriptTiming = interfaces.PerformanceScriptTiming;

pub const State = PerformanceScriptTiming.State;

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

/// Getter for startTime
pub fn get_startTime(instance: *runtime.Instance) ImplError!typedefs.DOMHighResTimeStamp {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for duration
pub fn get_duration(instance: *runtime.Instance) ImplError!typedefs.DOMHighResTimeStamp {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for name
pub fn get_name(instance: *runtime.Instance) ImplError!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for entryType
pub fn get_entryType(instance: *runtime.Instance) ImplError!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for invokerType
pub fn get_invokerType(instance: *runtime.Instance) ImplError!enums.ScriptInvokerType {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for invoker
pub fn get_invoker(instance: *runtime.Instance) ImplError!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for executionStart
pub fn get_executionStart(instance: *runtime.Instance) ImplError!typedefs.DOMHighResTimeStamp {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for sourceURL
pub fn get_sourceURL(instance: *runtime.Instance) ImplError!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for sourceFunctionName
pub fn get_sourceFunctionName(instance: *runtime.Instance) ImplError!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for sourceCharPosition
pub fn get_sourceCharPosition(instance: *runtime.Instance) ImplError!i64 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for pauseDuration
pub fn get_pauseDuration(instance: *runtime.Instance) ImplError!typedefs.DOMHighResTimeStamp {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for forcedStyleAndLayoutDuration
pub fn get_forcedStyleAndLayoutDuration(instance: *runtime.Instance) ImplError!typedefs.DOMHighResTimeStamp {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for window
pub fn get_window(instance: *runtime.Instance) ImplError!interfaces.Window {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for windowAttribution
pub fn get_windowAttribution(instance: *runtime.Instance) ImplError!enums.ScriptWindowAttribution {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: toJSON
pub fn call_toJSON(instance: *runtime.Instance) ImplError!*const anyopaque {
    _ = instance;
    return error.NotImplemented;
}

