//! Implementation for Fence interface
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
const Fence = interfaces.Fence;

pub const State = Fence.State;

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

/// Operation: reportEvent
pub fn call_reportEvent(instance: *runtime.Instance, event: typedefs.ReportEventType) ImplError!void {
    _ = instance;
    _ = event;
    return error.NotImplemented;
}

/// Operation: getNestedConfigs
pub fn call_getNestedConfigs(instance: *runtime.Instance) ImplError!*const anyopaque {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: setReportEventDataForAutomaticBeacons
pub fn call_setReportEventDataForAutomaticBeacons(instance: *runtime.Instance, event: dictionaries.FenceEvent) ImplError!void {
    _ = instance;
    _ = event;
    return error.NotImplemented;
}

/// Operation: disableUntrustedNetwork
pub fn call_disableUntrustedNetwork(instance: *runtime.Instance) ImplError!*const anyopaque {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: notifyEvent
pub fn call_notifyEvent(instance: *runtime.Instance, event: *runtime.Instance) ImplError!void {
    _ = instance;
    _ = event;
    return error.NotImplemented;
}

