//! Implementation for SourceBuffer interface
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
const SourceBuffer = interfaces.SourceBuffer;

pub const State = SourceBuffer.State;

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

/// Getter for mode
pub fn get_mode(instance: *runtime.Instance) ImplError!enums.AppendMode {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for updating
pub fn get_updating(instance: *runtime.Instance) ImplError!bool {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for buffered
pub fn get_buffered(instance: *runtime.Instance) ImplError!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for timestampOffset
pub fn get_timestampOffset(instance: *runtime.Instance) ImplError!f64 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for audioTracks
pub fn get_audioTracks(instance: *runtime.Instance) ImplError!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for videoTracks
pub fn get_videoTracks(instance: *runtime.Instance) ImplError!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for textTracks
pub fn get_textTracks(instance: *runtime.Instance) ImplError!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for appendWindowStart
pub fn get_appendWindowStart(instance: *runtime.Instance) ImplError!f64 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for appendWindowEnd
pub fn get_appendWindowEnd(instance: *runtime.Instance) ImplError!f64 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onupdatestart
pub fn get_onupdatestart(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onupdate
pub fn get_onupdate(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onupdateend
pub fn get_onupdateend(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onerror
pub fn get_onerror(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onabort
pub fn get_onabort(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Setter for mode
pub fn set_mode(instance: *runtime.Instance, value: enums.AppendMode) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for timestampOffset
pub fn set_timestampOffset(instance: *runtime.Instance, value: f64) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for appendWindowStart
pub fn set_appendWindowStart(instance: *runtime.Instance, value: f64) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for appendWindowEnd
pub fn set_appendWindowEnd(instance: *runtime.Instance, value: f64) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onupdatestart
pub fn set_onupdatestart(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onupdate
pub fn set_onupdate(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onupdateend
pub fn set_onupdateend(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onerror
pub fn set_onerror(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onabort
pub fn set_onabort(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Operation: appendBuffer
pub fn call_appendBuffer(instance: *runtime.Instance, data: typedefs.BufferSource) ImplError!void {
    _ = instance;
    _ = data;
    return error.NotImplemented;
}

/// Operation: abort
pub fn call_abort(instance: *runtime.Instance) ImplError!void {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: remove
pub fn call_remove(instance: *runtime.Instance, start: f64, end: f64) ImplError!void {
    _ = instance;
    _ = start;
    _ = end;
    return error.NotImplemented;
}

/// Operation: changeType
pub fn call_changeType(instance: *runtime.Instance, @"type": runtime.DOMString) ImplError!void {
    _ = instance;
    _ = @"type";
    return error.NotImplemented;
}

