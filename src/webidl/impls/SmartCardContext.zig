//! Implementation for SmartCardContext interface
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
const SmartCardContext = interfaces.SmartCardContext;

pub const State = SmartCardContext.State;

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

/// Operation: listReaders
pub fn call_listReaders(instance: *runtime.Instance) ImplError!*const anyopaque {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: getStatusChange
pub fn call_getStatusChange(instance: *runtime.Instance, readerStates: *const anyopaque, options: dictionaries.SmartCardGetStatusChangeOptions) ImplError!*const anyopaque {
    _ = instance;
    _ = readerStates;
    _ = options;
    return error.NotImplemented;
}

/// Operation: connect
pub fn call_connect(instance: *runtime.Instance, readerName: runtime.DOMString, accessMode: enums.SmartCardAccessMode, options: dictionaries.SmartCardConnectOptions) ImplError!*const anyopaque {
    _ = instance;
    _ = readerName;
    _ = accessMode;
    _ = options;
    return error.NotImplemented;
}

