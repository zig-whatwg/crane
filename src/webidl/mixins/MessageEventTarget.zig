//! Auto-generated mixin: MessageEventTarget
//! Delegates to impl for actual implementation.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const MessageEventTargetImpl = @import("impls").MessageEventTarget;

// Re-export types from impl
pub const impl = @import("impls").MessageEventTarget;

pub fn get_onmessage(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return MessageEventTargetImpl.get_onmessage(instance);
}

pub fn set_onmessage(instance: *runtime.Instance, value: typedefs.EventHandler) !void {
    return MessageEventTargetImpl.set_onmessage(instance, value);
}

pub fn get_onmessageerror(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return MessageEventTargetImpl.get_onmessageerror(instance);
}

pub fn set_onmessageerror(instance: *runtime.Instance, value: typedefs.EventHandler) !void {
    return MessageEventTargetImpl.set_onmessageerror(instance, value);
}

