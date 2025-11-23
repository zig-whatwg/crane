//! Implementation for ServiceWorkerContainer interface
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
const ServiceWorkerContainer = interfaces.ServiceWorkerContainer;

pub const State = ServiceWorkerContainer.State;

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

/// Getter for controller
pub fn get_controller(instance: *runtime.Instance) ImplError!interfaces.ServiceWorker {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for ready
pub fn get_ready(instance: *runtime.Instance) ImplError!*const anyopaque {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for oncontrollerchange
pub fn get_oncontrollerchange(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onmessage
pub fn get_onmessage(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onmessageerror
pub fn get_onmessageerror(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Setter for oncontrollerchange
pub fn set_oncontrollerchange(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
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

/// Setter for onmessageerror
pub fn set_onmessageerror(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Operation: startMessages
pub fn call_startMessages(instance: *runtime.Instance) ImplError!void {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: getRegistrations
pub fn call_getRegistrations(instance: *runtime.Instance) ImplError!*const anyopaque {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: getRegistration
pub fn call_getRegistration(instance: *runtime.Instance, clientURL: runtime.USVString) ImplError!*const anyopaque {
    _ = instance;
    _ = clientURL;
    return error.NotImplemented;
}

/// Operation: register
pub fn call_register(instance: *runtime.Instance, scriptURL: *const anyopaque, options: dictionaries.RegistrationOptions) ImplError!*const anyopaque {
    _ = instance;
    _ = scriptURL;
    _ = options;
    return error.NotImplemented;
}

