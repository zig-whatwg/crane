//! Implementation for FileSystemWritableFileStream interface
//!
//! This file is AUTO-GENERATED on first creation.
//! Add your custom implementation here.

const std = @import("std");
const runtime = @import("runtime");
const FileSystemWritableFileStream = @import("interfaces").FileSystemWritableFileStream;

pub const State = FileSystemWritableFileStream.State;

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
pub fn constructor(instance: *runtime.Instance, underlyingSink: anyopaque, strategy: anyopaque) !void {
    _ = instance;
    _ = underlyingSink;
    _ = strategy;
    // TODO: Implement constructor logic
}

/// Getter for locked
pub fn get_locked(instance: *runtime.Instance) ImplError!bool {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Operation: abort
pub fn call_abort(instance: *runtime.Instance, reason: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = reason;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: close
pub fn call_close(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: getWriter
pub fn call_getWriter(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: write
pub fn call_write(instance: *runtime.Instance, data: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = data;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: seek
pub fn call_seek(instance: *runtime.Instance, position: u64) ImplError!anyopaque {
    _ = instance;
    _ = position;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: truncate
pub fn call_truncate(instance: *runtime.Instance, size: u64) ImplError!anyopaque {
    _ = instance;
    _ = size;
    // TODO: Implement operation
    return error.NotImplemented;
}

