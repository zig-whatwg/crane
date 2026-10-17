//! Auto-generated mixin: SFrameDecryptorManager
//! Its members' delegates to the mixin's impl, which every interface that
//! includes it inherits by alias.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const SFrameDecryptorManagerImpl = @import("impls").SFrameDecryptorManager;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const CryptoKeyID = @import("typedefs").CryptoKeyID;
const EventHandler = @import("typedefs").EventHandler;
const CryptoKey = @import("interfaces").CryptoKey;

pub const impl = @import("impls").SFrameDecryptorManager;

/// The impl's process-wide hooks, installed once at process start
/// (crane.Process, through the root's process_hooks).
pub fn installHooks() void {
    const impls = @import("impls");
    if (comptime @hasDecl(impls, "SFrameDecryptorManager")) {
        if (comptime @hasDecl(impls.SFrameDecryptorManager, "installHooks")) impls.SFrameDecryptorManager.installHooks();
    }
}

const event_handlers = @import("dom").event_handlers;

pub fn get_onerror(instance: *runtime.Instance) anyerror!EventHandler {
    if (comptime @hasDecl(SFrameDecryptorManagerImpl, "get_onerror")) return try SFrameDecryptorManagerImpl.get_onerror(instance);
    return event_handlers.value(EventHandler, instance, "onerror");
}

pub fn set_onerror(instance: *runtime.Instance, value: EventHandler) anyerror!void {
    if (comptime @hasDecl(SFrameDecryptorManagerImpl, "set_onerror")) return try SFrameDecryptorManagerImpl.set_onerror(instance, value);
    try event_handlers.setValue(EventHandler, instance, "onerror", value);
}

pub fn call_addDecryptionKey(instance: *runtime.Instance, key: *runtime.Instance, keyId: CryptoKeyID) anyerror!runtime.JSValue {
    return try SFrameDecryptorManagerImpl.call_addDecryptionKey(instance, key, keyId);
}

pub fn call_removeDecryptionKey(instance: *runtime.Instance, keyId: CryptoKeyID) anyerror!runtime.JSValue {
    return try SFrameDecryptorManagerImpl.call_removeDecryptionKey(instance, keyId);
}

/// WebIDL: operations whose return type is a promise - an exception in
/// their steps becomes a rejected promise.
pub const promise_returning = .{
    "call_addDecryptionKey",
    "call_removeDecryptionKey",
};
