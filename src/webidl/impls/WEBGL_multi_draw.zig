//! Implementation for WEBGL_multi_draw interface
//!
//! This file is AUTO-GENERATED on first creation.
//! Add your custom implementation here.

const std = @import("std");
const runtime = @import("runtime");
const WEBGL_multi_draw = @import("interfaces").WEBGL_multi_draw;

pub const State = WEBGL_multi_draw.State;

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

/// Operation: multiDrawArraysWEBGL
pub fn call_multiDrawArraysWEBGL(instance: *runtime.Instance, mode: anyopaque, firstsList: anyopaque, firstsOffset: u64, countsList: anyopaque, countsOffset: u64, drawcount: anyopaque) ImplError!void {
    _ = instance;
    _ = mode;
    _ = firstsList;
    _ = firstsOffset;
    _ = countsList;
    _ = countsOffset;
    _ = drawcount;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: multiDrawElementsWEBGL
pub fn call_multiDrawElementsWEBGL(instance: *runtime.Instance, mode: anyopaque, countsList: anyopaque, countsOffset: u64, type: anyopaque, offsetsList: anyopaque, offsetsOffset: u64, drawcount: anyopaque) ImplError!void {
    _ = instance;
    _ = mode;
    _ = countsList;
    _ = countsOffset;
    _ = type;
    _ = offsetsList;
    _ = offsetsOffset;
    _ = drawcount;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: multiDrawArraysInstancedWEBGL
pub fn call_multiDrawArraysInstancedWEBGL(instance: *runtime.Instance, mode: anyopaque, firstsList: anyopaque, firstsOffset: u64, countsList: anyopaque, countsOffset: u64, instanceCountsList: anyopaque, instanceCountsOffset: u64, drawcount: anyopaque) ImplError!void {
    _ = instance;
    _ = mode;
    _ = firstsList;
    _ = firstsOffset;
    _ = countsList;
    _ = countsOffset;
    _ = instanceCountsList;
    _ = instanceCountsOffset;
    _ = drawcount;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: multiDrawElementsInstancedWEBGL
pub fn call_multiDrawElementsInstancedWEBGL(instance: *runtime.Instance, mode: anyopaque, countsList: anyopaque, countsOffset: u64, type: anyopaque, offsetsList: anyopaque, offsetsOffset: u64, instanceCountsList: anyopaque, instanceCountsOffset: u64, drawcount: anyopaque) ImplError!void {
    _ = instance;
    _ = mode;
    _ = countsList;
    _ = countsOffset;
    _ = type;
    _ = offsetsList;
    _ = offsetsOffset;
    _ = instanceCountsList;
    _ = instanceCountsOffset;
    _ = drawcount;
    // TODO: Implement operation
    return error.NotImplemented;
}

