//! Implementation for GPUCompilationMessage interface
//!
//! This file is AUTO-GENERATED on first creation.
//! Add your custom implementation here.

const std = @import("std");
const runtime = @import("runtime");
const GPUCompilationMessage = @import("interfaces").GPUCompilationMessage;

pub const State = GPUCompilationMessage.State;

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

/// Getter for message
pub fn get_message(instance: *runtime.Instance) ImplError!runtime.DOMString {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for type
pub fn get_type(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for lineNum
pub fn get_lineNum(instance: *runtime.Instance) ImplError!u64 {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for linePos
pub fn get_linePos(instance: *runtime.Instance) ImplError!u64 {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for offset
pub fn get_offset(instance: *runtime.Instance) ImplError!u64 {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for length
pub fn get_length(instance: *runtime.Instance) ImplError!u64 {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

