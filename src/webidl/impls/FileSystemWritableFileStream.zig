//! Implementation for FileSystemWritableFileStream interface

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const FileSystemWritableFileStream = interfaces.FileSystemWritableFileStream;

pub const State = FileSystemWritableFileStream.State;

pub const ImplError = error{
    NotImplemented,
};

/// Internal state for implementation-specific data
/// Implementations can replace this with a real struct containing:
/// - Private data not exposed via WebIDL attributes
/// - Cached computations, buffers, etc.
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
    _ = instance; // GC layer handles slab freeing - do NOT call runtime.Instance.deinit()
}

/// Operation: truncate
pub fn call_truncate(instance: *runtime.Instance, size: u64) anyerror!*const anyopaque {
    _ = instance;
    _ = size;
    return error.NotImplemented;
}

/// Operation: write
pub fn call_write(instance: *runtime.Instance, data: typedefs.FileSystemWriteChunkType) anyerror!*const anyopaque {
    _ = instance;
    _ = data;
    return error.NotImplemented;
}

/// Operation: seek
pub fn call_seek(instance: *runtime.Instance, position: u64) anyerror!*const anyopaque {
    _ = instance;
    _ = position;
    return error.NotImplemented;
}
