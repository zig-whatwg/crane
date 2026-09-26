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

pub fn get_onerror(instance: *runtime.Instance) anyerror!EventHandler {
    return try SFrameKeyManagementImpl.get_onerror(instance);
}

pub fn set_onerror(instance: *runtime.Instance, value: EventHandler) anyerror!void {
    try SFrameKeyManagementImpl.set_onerror(instance, value);
}

pub fn call_setEncryptionKey(instance: *runtime.Instance, key: *runtime.Instance, keyID: webidl.Opt(CryptoKeyID)) anyerror!runtime.JSValue {
    return try SFrameKeyManagementImpl.call_setEncryptionKey(instance, key, keyID);
}

/// WebIDL: operations whose return type is a promise - an exception in
/// their steps becomes a rejected promise.
pub const promise_returning = .{
    "call_setEncryptionKey",
};
