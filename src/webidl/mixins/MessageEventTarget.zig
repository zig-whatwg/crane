//! Auto-generated mixin: MessageEventTarget
//! Its members' delegates to the mixin's impl, which every interface that
//! includes it inherits by alias.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const MessageEventTargetImpl = @import("impls").MessageEventTarget;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const EventHandler = @import("typedefs").EventHandler;

pub const impl = @import("impls").MessageEventTarget;

pub fn get_onmessage(instance: *runtime.Instance) anyerror!EventHandler {
    return try MessageEventTargetImpl.get_onmessage(instance);
}

pub fn set_onmessage(instance: *runtime.Instance, value: EventHandler) anyerror!void {
    try MessageEventTargetImpl.set_onmessage(instance, value);
}

pub fn get_onmessageerror(instance: *runtime.Instance) anyerror!EventHandler {
    return try MessageEventTargetImpl.get_onmessageerror(instance);
}

pub fn set_onmessageerror(instance: *runtime.Instance, value: EventHandler) anyerror!void {
    try MessageEventTargetImpl.set_onmessageerror(instance, value);
}
