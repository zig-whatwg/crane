//! Auto-generated mixin: SFrameKeyManagement
//! Delegates to impl for actual implementation.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const SFrameKeyManagementImpl = @import("impls").SFrameKeyManagement;

// Re-export types from impl
pub const impl = @import("impls").SFrameKeyManagement;

pub fn get_onerror(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return SFrameKeyManagementImpl.get_onerror(instance);
}

pub fn set_onerror(instance: *runtime.Instance, value: typedefs.EventHandler) !void {
    return SFrameKeyManagementImpl.set_onerror(instance, value);
}

pub fn call_setEncryptionKey(instance: *runtime.Instance, key: *runtime.Instance, keyID: typedefs.CryptoKeyID) anyerror!void {
    return SFrameKeyManagementImpl.call_setEncryptionKey(instance, key, keyID);
}

