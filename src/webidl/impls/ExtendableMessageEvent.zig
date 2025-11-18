//! Implementation for ExtendableMessageEvent interface
//!
//! This file is AUTO-GENERATED on first creation.
//! Add your custom implementation here.

const std = @import("std");
const runtime = @import("runtime");
const ExtendableMessageEvent = @import("interfaces").ExtendableMessageEvent;

pub const State = ExtendableMessageEvent.State;

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
pub fn constructor(instance: *runtime.Instance, type: runtime.DOMString, eventInitDict: anyopaque) !void {
    _ = instance;
    _ = type;
    _ = eventInitDict;
    // TODO: Implement constructor logic
}

/// Getter for type
pub fn get_type(instance: *runtime.Instance) ImplError!runtime.DOMString {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for target
pub fn get_target(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for srcElement
pub fn get_srcElement(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for currentTarget
pub fn get_currentTarget(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for eventPhase
pub fn get_eventPhase(instance: *runtime.Instance) ImplError!u16 {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for cancelBubble
pub fn get_cancelBubble(instance: *runtime.Instance) ImplError!bool {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for bubbles
pub fn get_bubbles(instance: *runtime.Instance) ImplError!bool {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for cancelable
pub fn get_cancelable(instance: *runtime.Instance) ImplError!bool {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for returnValue
pub fn get_returnValue(instance: *runtime.Instance) ImplError!bool {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for defaultPrevented
pub fn get_defaultPrevented(instance: *runtime.Instance) ImplError!bool {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for composed
pub fn get_composed(instance: *runtime.Instance) ImplError!bool {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for isTrusted
pub fn get_isTrusted(instance: *runtime.Instance) ImplError!bool {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for timeStamp
pub fn get_timeStamp(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for data
pub fn get_data(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for origin
pub fn get_origin(instance: *runtime.Instance) ImplError!runtime.DOMString {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for lastEventId
pub fn get_lastEventId(instance: *runtime.Instance) ImplError!runtime.DOMString {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for source
pub fn get_source(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for ports
pub fn get_ports(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Setter for cancelBubble
pub fn set_cancelBubble(instance: *runtime.Instance, value: bool) ImplError!void {
    _ = instance;
    _ = value;
    // TODO: Implement setter
    return error.NotImplemented;
}

/// Setter for returnValue
pub fn set_returnValue(instance: *runtime.Instance, value: bool) ImplError!void {
    _ = instance;
    _ = value;
    // TODO: Implement setter
    return error.NotImplemented;
}

/// Operation: composedPath
pub fn call_composedPath(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: stopPropagation
pub fn call_stopPropagation(instance: *runtime.Instance) ImplError!void {
    _ = instance;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: stopImmediatePropagation
pub fn call_stopImmediatePropagation(instance: *runtime.Instance) ImplError!void {
    _ = instance;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: preventDefault
pub fn call_preventDefault(instance: *runtime.Instance) ImplError!void {
    _ = instance;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: initEvent
pub fn call_initEvent(instance: *runtime.Instance, type: runtime.DOMString, bubbles: bool, cancelable: bool) ImplError!void {
    _ = instance;
    _ = type;
    _ = bubbles;
    _ = cancelable;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: waitUntil
pub fn call_waitUntil(instance: *runtime.Instance, f: anyopaque) ImplError!void {
    _ = instance;
    _ = f;
    // TODO: Implement operation
    return error.NotImplemented;
}

