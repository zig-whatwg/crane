//! Auto-generated mixin: SFrameKeyManagement
//! Its members' delegates to the mixin's impl, which every interface that
//! includes it inherits by alias.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const SFrameKeyManagementImpl = @import("impls").SFrameKeyManagement;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const CryptoKeyID = @import("typedefs").CryptoKeyID;
const EventHandler = @import("typedefs").EventHandler;
const CryptoKey = @import("interfaces").CryptoKey;

pub const impl = @import("impls").SFrameKeyManagement;

/// The impl's process-wide hooks, installed once at process start
/// (crane.Process, through the root's process_hooks).
pub fn installHooks() void {
    const impls = @import("impls");
    if (comptime @hasDecl(impls, "SFrameKeyManagement")) {
        if (comptime @hasDecl(impls.SFrameKeyManagement, "installHooks")) impls.SFrameKeyManagement.installHooks();
    }
}

const event_handlers = @import("dom").event_handlers;

pub fn get_onerror(instance: *runtime.Instance) anyerror!EventHandler {
    if (comptime @hasDecl(SFrameKeyManagementImpl, "get_onerror")) return try SFrameKeyManagementImpl.get_onerror(instance);
    return event_handlers.value(EventHandler, instance, "onerror");
}

pub fn set_onerror(instance: *runtime.Instance, value: EventHandler) anyerror!void {
    if (comptime @hasDecl(SFrameKeyManagementImpl, "set_onerror")) return try SFrameKeyManagementImpl.set_onerror(instance, value);
    try event_handlers.setValue(EventHandler, instance, "onerror", value);
}

pub fn call_setEncryptionKey(instance: *runtime.Instance, key: *runtime.Instance, keyID: webidl.Opt(CryptoKeyID)) anyerror!runtime.JSValue {
    return try SFrameKeyManagementImpl.call_setEncryptionKey(instance, key, keyID);
}

/// WebIDL interface types: the interface each interface-typed argument
/// and attribute value converts to - a TypeError unless the value implements
/// it (function, argument index - an attribute setter's value is 0 -,
/// interface; a nullable, sequence or record value by its elements').
pub const interface_arguments = .{
    .{ "call_setEncryptionKey", 0, "CryptoKey" },
};

/// WebIDL: operations whose return type is a promise - an exception in
/// their steps becomes a rejected promise.
pub const promise_returning = .{
    "call_setEncryptionKey",
};
