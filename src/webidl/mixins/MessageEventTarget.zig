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

/// The impl's process-wide hooks, installed once at process start
/// (crane.Process, through the root's process_hooks).
pub fn installHooks() void {
    const impls = @import("impls");
    if (comptime @hasDecl(impls, "MessageEventTarget")) {
        if (comptime @hasDecl(impls.MessageEventTarget, "installHooks")) impls.MessageEventTarget.installHooks();
    }
}

const event_handlers = @import("dom").event_handlers;

pub fn get_onmessage(instance: *runtime.Instance) anyerror!EventHandler {
    if (comptime @hasDecl(MessageEventTargetImpl, "get_onmessage")) return try MessageEventTargetImpl.get_onmessage(instance);
    return event_handlers.value(EventHandler, instance, "onmessage");
}

pub fn set_onmessage(instance: *runtime.Instance, value: EventHandler) anyerror!void {
    if (comptime @hasDecl(MessageEventTargetImpl, "set_onmessage")) return try MessageEventTargetImpl.set_onmessage(instance, value);
    try event_handlers.setValue(EventHandler, instance, "onmessage", value);
}

pub fn get_onmessageerror(instance: *runtime.Instance) anyerror!EventHandler {
    if (comptime @hasDecl(MessageEventTargetImpl, "get_onmessageerror")) return try MessageEventTargetImpl.get_onmessageerror(instance);
    return event_handlers.value(EventHandler, instance, "onmessageerror");
}

pub fn set_onmessageerror(instance: *runtime.Instance, value: EventHandler) anyerror!void {
    if (comptime @hasDecl(MessageEventTargetImpl, "set_onmessageerror")) return try MessageEventTargetImpl.set_onmessageerror(instance, value);
    try event_handlers.setValue(EventHandler, instance, "onmessageerror", value);
}
