//! Auto-generated mixin: SFrameDecrypterManager
//! Delegates to impl for actual implementation.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const SFrameDecrypterManagerImpl = @import("impls").SFrameDecrypterManager;

// Re-export types from impl
pub const impl = @import("impls").SFrameDecrypterManager;

pub fn get_onerror(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return SFrameDecrypterManagerImpl.get_onerror(instance);
}

pub fn set_onerror(instance: *runtime.Instance, value: typedefs.EventHandler) !void {
    return SFrameDecrypterManagerImpl.set_onerror(instance, value);
}

pub fn call_addDecryptionKey(instance: *runtime.Instance, key: *runtime.Instance, keyId: typedefs.CryptoKeyID) anyerror!void {
    return SFrameDecrypterManagerImpl.call_addDecryptionKey(instance, key, keyId);
}

pub fn call_removeDecryptionKey(instance: *runtime.Instance, keyId: typedefs.CryptoKeyID) anyerror!void {
    return SFrameDecrypterManagerImpl.call_removeDecryptionKey(instance, keyId);
}

