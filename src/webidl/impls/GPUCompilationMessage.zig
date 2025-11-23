//! Implementation for GPUCompilationMessage interface
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
const GPUCompilationMessage = interfaces.GPUCompilationMessage;

pub const State = GPUCompilationMessage.State;

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

/// Getter for message
pub fn get_message(instance: *runtime.Instance) ImplError!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for type
pub fn get_type(instance: *runtime.Instance) ImplError!enums.GPUCompilationMessageType {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for lineNum
pub fn get_lineNum(instance: *runtime.Instance) ImplError!u64 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for linePos
pub fn get_linePos(instance: *runtime.Instance) ImplError!u64 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for offset
pub fn get_offset(instance: *runtime.Instance) ImplError!u64 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for length
pub fn get_length(instance: *runtime.Instance) ImplError!u64 {
    _ = instance;
    return error.NotImplemented;
}

