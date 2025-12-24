//! Auto-generated mixin: SFrameEncrypterManager
//! Delegates to impl for actual implementation.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const SFrameEncrypterManagerImpl = @import("impls").SFrameEncrypterManager;

// Re-export types from impl
pub const impl = @import("impls").SFrameEncrypterManager;

pub fn get_onerror(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return SFrameEncrypterManagerImpl.get_onerror(instance);
}

pub fn set_onerror(instance: *runtime.Instance, value: typedefs.EventHandler) !void {
    return SFrameEncrypterManagerImpl.set_onerror(instance, value);
}

pub fn call_setEncryptionKey(instance: *runtime.Instance, key: *runtime.Instance, keyId: typedefs.CryptoKeyID) anyerror!void {
    return SFrameEncrypterManagerImpl.call_setEncryptionKey(instance, key, keyId);
}

