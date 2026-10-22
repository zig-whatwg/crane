//! Auto-generated mixin: PowerfulFeatureObserver
//! Its members' delegates to the mixin's impl, which every interface that
//! includes it inherits by alias.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const PowerfulFeatureObserverImpl = @import("impls").PowerfulFeatureObserver;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const PermissionState = @import("enums").PermissionState;
const EventHandler = @import("typedefs").EventHandler;

pub const impl = @import("impls").PowerfulFeatureObserver;

/// The impl's process-wide hooks, installed once at process start
/// (crane.Process, through the root's process_hooks).
pub fn installHooks() void {
    const impls = @import("impls");
    if (comptime @hasDecl(impls, "PowerfulFeatureObserver")) {
        if (comptime @hasDecl(impls.PowerfulFeatureObserver, "installHooks")) impls.PowerfulFeatureObserver.installHooks();
    }
}

pub fn get_initialPermissionStatus(instance: *runtime.Instance) anyerror!PermissionState {
    return try PowerfulFeatureObserverImpl.get_initialPermissionStatus(instance);
}

pub fn get_permissionStatus(instance: *runtime.Instance) anyerror!PermissionState {
    return try PowerfulFeatureObserverImpl.get_permissionStatus(instance);
}

const event_handlers = @import("dom").event_handlers;

pub fn get_onpromptaction(instance: *runtime.Instance) anyerror!EventHandler {
    if (comptime @hasDecl(PowerfulFeatureObserverImpl, "get_onpromptaction")) return try PowerfulFeatureObserverImpl.get_onpromptaction(instance);
    return event_handlers.value(EventHandler, instance, "onpromptaction");
}

pub fn set_onpromptaction(instance: *runtime.Instance, value: EventHandler) anyerror!void {
    if (comptime @hasDecl(PowerfulFeatureObserverImpl, "set_onpromptaction")) return try PowerfulFeatureObserverImpl.set_onpromptaction(instance, value);
    try event_handlers.setValue(EventHandler, instance, "onpromptaction", value);
}

pub fn get_onpromptdismiss(instance: *runtime.Instance) anyerror!EventHandler {
    if (comptime @hasDecl(PowerfulFeatureObserverImpl, "get_onpromptdismiss")) return try PowerfulFeatureObserverImpl.get_onpromptdismiss(instance);
    return event_handlers.value(EventHandler, instance, "onpromptdismiss");
}

pub fn set_onpromptdismiss(instance: *runtime.Instance, value: EventHandler) anyerror!void {
    if (comptime @hasDecl(PowerfulFeatureObserverImpl, "set_onpromptdismiss")) return try PowerfulFeatureObserverImpl.set_onpromptdismiss(instance, value);
    try event_handlers.setValue(EventHandler, instance, "onpromptdismiss", value);
}

/// Nullable callback attributes with [LegacyTreatNonObjectAsNull].
pub const legacy_treat_non_object_as_null = .{ "set_onpromptaction", "set_onpromptdismiss" };
