//! Implementation for XMLHttpRequestEventTarget interface
//!
//! XMLHttpRequestEventTarget provides event handler properties for XHR events.
//! Spec: https://xhr.spec.whatwg.org/#xmlhttprequesteventtarget
//!
//! Its seven attributes are event handler IDL attributes (HTML §8.1.8.1), and
//! like every other one they keep their values in EventTarget's event handler
//! map - an XMLHttpRequestEventTarget is an EventTarget. They used to live in
//! this interface's generated state, which nothing disposed and dispatch could
//! not see: the XHR impl invoked them itself, after every listener and with
//! `this` undefined, and each one pinned its page for the rest of the process.
//! The map owns its values, and dispatch runs them where they were activated.
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const XMLHttpRequestEventTarget = interfaces.XMLHttpRequestEventTarget;
const EventTargetImpl = @import("EventTarget.zig");

pub const State = XMLHttpRequestEventTarget.State;

pub const ImplError = error{
    NotImplemented,
};

/// Internal state for implementation-specific data
pub const InternalState = struct {};

/// Initialize instance (creates the instance)
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    // An XMLHttpRequestEventTarget is an EventTarget: its handlers live in
    // EventTarget's map, and events are dispatched at it.
    return EventTargetImpl.init(allocator, StateType, vtable, ctx);
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    // Releases the event handler map's values with the rest of EventTarget's
    // state. GC layer handles slab freeing - do NOT call runtime.Instance.deinit()
    EventTargetImpl.deinit(instance);
}

/// Getter for onloadstart
pub fn get_onloadstart(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return EventTargetImpl.eventHandler(typedefs.EventHandler, instance, "loadstart");
}

/// Getter for onprogress
pub fn get_onprogress(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return EventTargetImpl.eventHandler(typedefs.EventHandler, instance, "progress");
}

/// Getter for onabort
pub fn get_onabort(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return EventTargetImpl.eventHandler(typedefs.EventHandler, instance, "abort");
}

/// Getter for onerror
pub fn get_onerror(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return EventTargetImpl.eventHandler(typedefs.EventHandler, instance, "error");
}

/// Getter for onload
pub fn get_onload(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return EventTargetImpl.eventHandler(typedefs.EventHandler, instance, "load");
}

/// Getter for ontimeout
pub fn get_ontimeout(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return EventTargetImpl.eventHandler(typedefs.EventHandler, instance, "timeout");
}

/// Getter for onloadend
pub fn get_onloadend(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return EventTargetImpl.eventHandler(typedefs.EventHandler, instance, "loadend");
}

/// Setter for onloadstart
pub fn set_onloadstart(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try EventTargetImpl.setEventHandler(typedefs.EventHandler, instance, "loadstart", value);
}

/// Setter for onprogress
pub fn set_onprogress(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try EventTargetImpl.setEventHandler(typedefs.EventHandler, instance, "progress", value);
}

/// Setter for onabort
pub fn set_onabort(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try EventTargetImpl.setEventHandler(typedefs.EventHandler, instance, "abort", value);
}

/// Setter for onerror
pub fn set_onerror(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try EventTargetImpl.setEventHandler(typedefs.EventHandler, instance, "error", value);
}

/// Setter for onload
pub fn set_onload(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try EventTargetImpl.setEventHandler(typedefs.EventHandler, instance, "load", value);
}

/// Setter for ontimeout
pub fn set_ontimeout(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try EventTargetImpl.setEventHandler(typedefs.EventHandler, instance, "timeout", value);
}

/// Setter for onloadend
pub fn set_onloadend(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try EventTargetImpl.setEventHandler(typedefs.EventHandler, instance, "loadend", value);
}
