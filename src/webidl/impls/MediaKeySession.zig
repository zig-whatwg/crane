//! Implementation for MediaKeySession interface
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
const MediaKeySession = interfaces.MediaKeySession;

pub const State = MediaKeySession.State;

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

/// Getter for sessionId
pub fn get_sessionId(instance: *runtime.Instance) ImplError!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for expiration
pub fn get_expiration(instance: *runtime.Instance) ImplError!f64 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for closed
pub fn get_closed(instance: *runtime.Instance) ImplError!*const anyopaque {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for keyStatuses
pub fn get_keyStatuses(instance: *runtime.Instance) ImplError!interfaces.MediaKeyStatusMap {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onkeystatuseschange
pub fn get_onkeystatuseschange(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onmessage
pub fn get_onmessage(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Setter for onkeystatuseschange
pub fn set_onkeystatuseschange(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onmessage
pub fn set_onmessage(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Operation: update
pub fn call_update(instance: *runtime.Instance, response: typedefs.BufferSource) ImplError!*const anyopaque {
    _ = instance;
    _ = response;
    return error.NotImplemented;
}

/// Operation: remove
pub fn call_remove(instance: *runtime.Instance) ImplError!*const anyopaque {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: load
pub fn call_load(instance: *runtime.Instance, sessionId: runtime.DOMString) ImplError!*const anyopaque {
    _ = instance;
    _ = sessionId;
    return error.NotImplemented;
}

/// Operation: close
pub fn call_close(instance: *runtime.Instance) ImplError!*const anyopaque {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: generateRequest
pub fn call_generateRequest(instance: *runtime.Instance, initDataType: runtime.DOMString, initData: typedefs.BufferSource) ImplError!*const anyopaque {
    _ = instance;
    _ = initDataType;
    _ = initData;
    return error.NotImplemented;
}

