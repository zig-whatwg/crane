//! Auto-generated mixin: SFrameEncryptorManager
//! Its members' delegates to the mixin's impl, which every interface that
//! includes it inherits by alias.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const SFrameEncryptorManagerImpl = @import("impls").SFrameEncryptorManager;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const CryptoKeyID = @import("typedefs").CryptoKeyID;
const CryptoKey = @import("interfaces").CryptoKey;

pub const impl = @import("impls").SFrameEncryptorManager;

/// The impl's process-wide hooks, installed once at process start
/// (crane.Process, through the root's process_hooks).
pub fn installHooks() void {
    const impls = @import("impls");
    if (comptime @hasDecl(impls, "SFrameEncryptorManager")) {
        if (comptime @hasDecl(impls.SFrameEncryptorManager, "installHooks")) impls.SFrameEncryptorManager.installHooks();
    }
}

pub fn call_setEncryptionKey(instance: *runtime.Instance, key: *runtime.Instance, keyId: CryptoKeyID) anyerror!runtime.JSValue {
    return try SFrameEncryptorManagerImpl.call_setEncryptionKey(instance, key, keyId);
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
