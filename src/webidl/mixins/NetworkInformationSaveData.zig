//! Auto-generated mixin: NetworkInformationSaveData
//! Its members' delegates to the mixin's impl, which every interface that
//! includes it inherits by alias.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const NetworkInformationSaveDataImpl = @import("impls").NetworkInformationSaveData;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");

pub const impl = @import("impls").NetworkInformationSaveData;

/// Extended attributes: [SameObject]
pub fn get_saveData(instance: *runtime.Instance) anyerror!bool {
    return try NetworkInformationSaveDataImpl.get_saveData(instance);
}
