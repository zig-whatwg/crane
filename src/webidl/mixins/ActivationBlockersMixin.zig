//! Auto-generated mixin: ActivationBlockersMixin
//! Its members' delegates to the mixin's impl, which every interface that
//! includes it inherits by alias.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const ActivationBlockersMixinImpl = @import("impls").ActivationBlockersMixin;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const ActivationBlockersMixinBlockerReason = @import("enums").ActivationBlockersMixinBlockerReason;
const EventHandler = @import("typedefs").EventHandler;

pub const impl = @import("impls").ActivationBlockersMixin;

/// The impl's process-wide hooks, installed once at process start
/// (crane.Process, through the root's process_hooks).
pub fn installHooks() void {
    const impls = @import("impls");
    if (comptime @hasDecl(impls, "ActivationBlockersMixin")) {
        if (comptime @hasDecl(impls.ActivationBlockersMixin, "installHooks")) impls.ActivationBlockersMixin.installHooks();
    }
}

pub fn get_isValid(instance: *runtime.Instance) anyerror!bool {
    return try ActivationBlockersMixinImpl.get_isValid(instance);
}

pub fn get_invalidReason(instance: *runtime.Instance) anyerror!ActivationBlockersMixinBlockerReason {
    return try ActivationBlockersMixinImpl.get_invalidReason(instance);
}

const event_handlers = @import("dom").event_handlers;

pub fn get_onvalidationstatuschange(instance: *runtime.Instance) anyerror!EventHandler {
    if (comptime @hasDecl(ActivationBlockersMixinImpl, "get_onvalidationstatuschange")) return try ActivationBlockersMixinImpl.get_onvalidationstatuschange(instance);
    return event_handlers.value(EventHandler, instance, "onvalidationstatuschange");
}

pub fn set_onvalidationstatuschange(instance: *runtime.Instance, value: EventHandler) anyerror!void {
    if (comptime @hasDecl(ActivationBlockersMixinImpl, "set_onvalidationstatuschange")) return try ActivationBlockersMixinImpl.set_onvalidationstatuschange(instance, value);
    try event_handlers.setValue(EventHandler, instance, "onvalidationstatuschange", value);
}
