//! Auto-generated mixin: NetworkInformationSaveData
//! Delegates to impl for actual implementation.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const NetworkInformationSaveDataImpl = @import("impls").NetworkInformationSaveData;

// Re-export types from impl
pub const impl = @import("impls").NetworkInformationSaveData;

pub fn get_saveData(instance: *runtime.Instance) anyerror!bool {
    return NetworkInformationSaveDataImpl.get_saveData(instance);
}

