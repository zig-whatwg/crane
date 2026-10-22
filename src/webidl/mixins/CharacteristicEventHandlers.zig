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

/// The impl's process-wide hooks, installed once at process start
/// (crane.Process, through the root's process_hooks).
pub fn installHooks() void {
    const impls = @import("impls");
    if (comptime @hasDecl(impls, "CharacteristicEventHandlers")) {
        if (comptime @hasDecl(impls.CharacteristicEventHandlers, "installHooks")) impls.CharacteristicEventHandlers.installHooks();
    }
}

const event_handlers = @import("dom").event_handlers;

pub fn get_oncharacteristicvaluechanged(instance: *runtime.Instance) anyerror!EventHandler {
    if (comptime @hasDecl(CharacteristicEventHandlersImpl, "get_oncharacteristicvaluechanged")) return try CharacteristicEventHandlersImpl.get_oncharacteristicvaluechanged(instance);
    return event_handlers.value(EventHandler, instance, "oncharacteristicvaluechanged");
}

pub fn set_oncharacteristicvaluechanged(instance: *runtime.Instance, value: EventHandler) anyerror!void {
    if (comptime @hasDecl(CharacteristicEventHandlersImpl, "set_oncharacteristicvaluechanged")) return try CharacteristicEventHandlersImpl.set_oncharacteristicvaluechanged(instance, value);
    try event_handlers.setValue(EventHandler, instance, "oncharacteristicvaluechanged", value);
}

/// Nullable callback attributes with [LegacyTreatNonObjectAsNull].
pub const legacy_treat_non_object_as_null = .{"set_oncharacteristicvaluechanged"};
