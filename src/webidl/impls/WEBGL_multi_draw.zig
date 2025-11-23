//! Implementation for WEBGL_multi_draw interface
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
const WEBGL_multi_draw = interfaces.WEBGL_multi_draw;

pub const State = WEBGL_multi_draw.State;

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

/// Operation: multiDrawArraysWEBGL
pub fn call_multiDrawArraysWEBGL(instance: *runtime.Instance, mode: typedefs.GLenum, firstsList: *const anyopaque, firstsOffset: u64, countsList: *const anyopaque, countsOffset: u64, drawcount: typedefs.GLsizei) ImplError!void {
    _ = instance;
    _ = mode;
    _ = firstsList;
    _ = firstsOffset;
    _ = countsList;
    _ = countsOffset;
    _ = drawcount;
    return error.NotImplemented;
}

/// Operation: multiDrawElementsWEBGL
pub fn call_multiDrawElementsWEBGL(instance: *runtime.Instance, mode: typedefs.GLenum, countsList: *const anyopaque, countsOffset: u64, @"type": typedefs.GLenum, offsetsList: *const anyopaque, offsetsOffset: u64, drawcount: typedefs.GLsizei) ImplError!void {
    _ = instance;
    _ = mode;
    _ = countsList;
    _ = countsOffset;
    _ = @"type";
    _ = offsetsList;
    _ = offsetsOffset;
    _ = drawcount;
    return error.NotImplemented;
}

/// Operation: multiDrawArraysInstancedWEBGL
pub fn call_multiDrawArraysInstancedWEBGL(instance: *runtime.Instance, mode: typedefs.GLenum, firstsList: *const anyopaque, firstsOffset: u64, countsList: *const anyopaque, countsOffset: u64, instanceCountsList: *const anyopaque, instanceCountsOffset: u64, drawcount: typedefs.GLsizei) ImplError!void {
    _ = instance;
    _ = mode;
    _ = firstsList;
    _ = firstsOffset;
    _ = countsList;
    _ = countsOffset;
    _ = instanceCountsList;
    _ = instanceCountsOffset;
    _ = drawcount;
    return error.NotImplemented;
}

/// Operation: multiDrawElementsInstancedWEBGL
pub fn call_multiDrawElementsInstancedWEBGL(instance: *runtime.Instance, mode: typedefs.GLenum, countsList: *const anyopaque, countsOffset: u64, @"type": typedefs.GLenum, offsetsList: *const anyopaque, offsetsOffset: u64, instanceCountsList: *const anyopaque, instanceCountsOffset: u64, drawcount: typedefs.GLsizei) ImplError!void {
    _ = instance;
    _ = mode;
    _ = countsList;
    _ = countsOffset;
    _ = @"type";
    _ = offsetsList;
    _ = offsetsOffset;
    _ = instanceCountsList;
    _ = instanceCountsOffset;
    _ = drawcount;
    return error.NotImplemented;
}

