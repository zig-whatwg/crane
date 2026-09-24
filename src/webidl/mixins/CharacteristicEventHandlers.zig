//! Auto-generated mixin: CharacteristicEventHandlers
//! Its members' delegates to the mixin's impl, which every interface that
//! includes it inherits by alias.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const CharacteristicEventHandlersImpl = @import("impls").CharacteristicEventHandlers;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const EventHandler = @import("typedefs").EventHandler;

pub const impl = @import("impls").CharacteristicEventHandlers;

pub fn get_oncharacteristicvaluechanged(instance: *runtime.Instance) anyerror!EventHandler {
    return try CharacteristicEventHandlersImpl.get_oncharacteristicvaluechanged(instance);
}

pub fn set_oncharacteristicvaluechanged(instance: *runtime.Instance, value: EventHandler) anyerror!void {
    try CharacteristicEventHandlersImpl.set_oncharacteristicvaluechanged(instance, value);
}
