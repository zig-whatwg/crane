//! Auto-generated mixin: CharacteristicEventHandlers
//! Delegates to impl for actual implementation.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const CharacteristicEventHandlersImpl = @import("impls").CharacteristicEventHandlers;

// Re-export types from impl
pub const impl = @import("impls").CharacteristicEventHandlers;

pub fn get_oncharacteristicvaluechanged(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return CharacteristicEventHandlersImpl.get_oncharacteristicvaluechanged(instance);
}

pub fn set_oncharacteristicvaluechanged(instance: *runtime.Instance, value: typedefs.EventHandler) !void {
    return CharacteristicEventHandlersImpl.set_oncharacteristicvaluechanged(instance, value);
}

