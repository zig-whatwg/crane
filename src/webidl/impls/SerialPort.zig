//! Implementation for SerialPort interface
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
const SerialPort = interfaces.SerialPort;

pub const State = SerialPort.State;

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

/// Getter for onconnect
pub fn get_onconnect(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for ondisconnect
pub fn get_ondisconnect(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for connected
pub fn get_connected(instance: *runtime.Instance) ImplError!bool {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for readable
pub fn get_readable(instance: *runtime.Instance) ImplError!interfaces.ReadableStream {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for writable
pub fn get_writable(instance: *runtime.Instance) ImplError!interfaces.WritableStream {
    _ = instance;
    return error.NotImplemented;
}

/// Setter for onconnect
pub fn set_onconnect(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for ondisconnect
pub fn set_ondisconnect(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Operation: forget
pub fn call_forget(instance: *runtime.Instance) ImplError!*const anyopaque {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: getInfo
pub fn call_getInfo(instance: *runtime.Instance) ImplError!dictionaries.SerialPortInfo {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: open
pub fn call_open(instance: *runtime.Instance, options: dictionaries.SerialOptions) ImplError!*const anyopaque {
    _ = instance;
    _ = options;
    return error.NotImplemented;
}

/// Operation: setSignals
pub fn call_setSignals(instance: *runtime.Instance, signals: dictionaries.SerialOutputSignals) ImplError!*const anyopaque {
    _ = instance;
    _ = signals;
    return error.NotImplemented;
}

/// Operation: getSignals
pub fn call_getSignals(instance: *runtime.Instance) ImplError!*const anyopaque {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: close
pub fn call_close(instance: *runtime.Instance) ImplError!*const anyopaque {
    _ = instance;
    return error.NotImplemented;
}

