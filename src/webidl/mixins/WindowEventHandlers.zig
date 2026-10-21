//! Auto-generated mixin: WindowEventHandlers
//! Its members' delegates to the mixin's impl, which every interface that
//! includes it inherits by alias.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const WindowEventHandlersImpl = @import("impls").WindowEventHandlers;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const OnBeforeUnloadEventHandler = @import("typedefs").OnBeforeUnloadEventHandler;
const EventHandler = @import("typedefs").EventHandler;

pub const impl = @import("impls").WindowEventHandlers;

/// The impl's process-wide hooks, installed once at process start
/// (crane.Process, through the root's process_hooks).
pub fn installHooks() void {
    const impls = @import("impls");
    if (comptime @hasDecl(impls, "WindowEventHandlers")) {
        if (comptime @hasDecl(impls.WindowEventHandlers, "installHooks")) impls.WindowEventHandlers.installHooks();
    }
}

const event_handlers = @import("dom").event_handlers;

pub fn get_onafterprint(instance: *runtime.Instance) anyerror!EventHandler {
    if (comptime @hasDecl(WindowEventHandlersImpl, "get_onafterprint")) return try WindowEventHandlersImpl.get_onafterprint(instance);
    return event_handlers.value(EventHandler, instance, "onafterprint");
}

pub fn set_onafterprint(instance: *runtime.Instance, value: EventHandler) anyerror!void {
    if (comptime @hasDecl(WindowEventHandlersImpl, "set_onafterprint")) return try WindowEventHandlersImpl.set_onafterprint(instance, value);
    try event_handlers.setValue(EventHandler, instance, "onafterprint", value);
}

pub fn get_onbeforeprint(instance: *runtime.Instance) anyerror!EventHandler {
    if (comptime @hasDecl(WindowEventHandlersImpl, "get_onbeforeprint")) return try WindowEventHandlersImpl.get_onbeforeprint(instance);
    return event_handlers.value(EventHandler, instance, "onbeforeprint");
}

pub fn set_onbeforeprint(instance: *runtime.Instance, value: EventHandler) anyerror!void {
    if (comptime @hasDecl(WindowEventHandlersImpl, "set_onbeforeprint")) return try WindowEventHandlersImpl.set_onbeforeprint(instance, value);
    try event_handlers.setValue(EventHandler, instance, "onbeforeprint", value);
}

pub fn get_onbeforeunload(instance: *runtime.Instance) anyerror!OnBeforeUnloadEventHandler {
    if (comptime @hasDecl(WindowEventHandlersImpl, "get_onbeforeunload")) return try WindowEventHandlersImpl.get_onbeforeunload(instance);
    return event_handlers.value(OnBeforeUnloadEventHandler, instance, "onbeforeunload");
}

pub fn set_onbeforeunload(instance: *runtime.Instance, value: OnBeforeUnloadEventHandler) anyerror!void {
    if (comptime @hasDecl(WindowEventHandlersImpl, "set_onbeforeunload")) return try WindowEventHandlersImpl.set_onbeforeunload(instance, value);
    try event_handlers.setValue(OnBeforeUnloadEventHandler, instance, "onbeforeunload", value);
}

pub fn get_onhashchange(instance: *runtime.Instance) anyerror!EventHandler {
    if (comptime @hasDecl(WindowEventHandlersImpl, "get_onhashchange")) return try WindowEventHandlersImpl.get_onhashchange(instance);
    return event_handlers.value(EventHandler, instance, "onhashchange");
}

pub fn set_onhashchange(instance: *runtime.Instance, value: EventHandler) anyerror!void {
    if (comptime @hasDecl(WindowEventHandlersImpl, "set_onhashchange")) return try WindowEventHandlersImpl.set_onhashchange(instance, value);
    try event_handlers.setValue(EventHandler, instance, "onhashchange", value);
}

pub fn get_onlanguagechange(instance: *runtime.Instance) anyerror!EventHandler {
    if (comptime @hasDecl(WindowEventHandlersImpl, "get_onlanguagechange")) return try WindowEventHandlersImpl.get_onlanguagechange(instance);
    return event_handlers.value(EventHandler, instance, "onlanguagechange");
}

pub fn set_onlanguagechange(instance: *runtime.Instance, value: EventHandler) anyerror!void {
    if (comptime @hasDecl(WindowEventHandlersImpl, "set_onlanguagechange")) return try WindowEventHandlersImpl.set_onlanguagechange(instance, value);
    try event_handlers.setValue(EventHandler, instance, "onlanguagechange", value);
}

pub fn get_onmessage(instance: *runtime.Instance) anyerror!EventHandler {
    if (comptime @hasDecl(WindowEventHandlersImpl, "get_onmessage")) return try WindowEventHandlersImpl.get_onmessage(instance);
    return event_handlers.value(EventHandler, instance, "onmessage");
}

pub fn set_onmessage(instance: *runtime.Instance, value: EventHandler) anyerror!void {
    if (comptime @hasDecl(WindowEventHandlersImpl, "set_onmessage")) return try WindowEventHandlersImpl.set_onmessage(instance, value);
    try event_handlers.setValue(EventHandler, instance, "onmessage", value);
}

pub fn get_onmessageerror(instance: *runtime.Instance) anyerror!EventHandler {
    if (comptime @hasDecl(WindowEventHandlersImpl, "get_onmessageerror")) return try WindowEventHandlersImpl.get_onmessageerror(instance);
    return event_handlers.value(EventHandler, instance, "onmessageerror");
}

pub fn set_onmessageerror(instance: *runtime.Instance, value: EventHandler) anyerror!void {
    if (comptime @hasDecl(WindowEventHandlersImpl, "set_onmessageerror")) return try WindowEventHandlersImpl.set_onmessageerror(instance, value);
    try event_handlers.setValue(EventHandler, instance, "onmessageerror", value);
}

pub fn get_onoffline(instance: *runtime.Instance) anyerror!EventHandler {
    if (comptime @hasDecl(WindowEventHandlersImpl, "get_onoffline")) return try WindowEventHandlersImpl.get_onoffline(instance);
    return event_handlers.value(EventHandler, instance, "onoffline");
}

pub fn set_onoffline(instance: *runtime.Instance, value: EventHandler) anyerror!void {
    if (comptime @hasDecl(WindowEventHandlersImpl, "set_onoffline")) return try WindowEventHandlersImpl.set_onoffline(instance, value);
    try event_handlers.setValue(EventHandler, instance, "onoffline", value);
}

pub fn get_ononline(instance: *runtime.Instance) anyerror!EventHandler {
    if (comptime @hasDecl(WindowEventHandlersImpl, "get_ononline")) return try WindowEventHandlersImpl.get_ononline(instance);
    return event_handlers.value(EventHandler, instance, "ononline");
}

pub fn set_ononline(instance: *runtime.Instance, value: EventHandler) anyerror!void {
    if (comptime @hasDecl(WindowEventHandlersImpl, "set_ononline")) return try WindowEventHandlersImpl.set_ononline(instance, value);
    try event_handlers.setValue(EventHandler, instance, "ononline", value);
}

pub fn get_onpagehide(instance: *runtime.Instance) anyerror!EventHandler {
    if (comptime @hasDecl(WindowEventHandlersImpl, "get_onpagehide")) return try WindowEventHandlersImpl.get_onpagehide(instance);
    return event_handlers.value(EventHandler, instance, "onpagehide");
}

pub fn set_onpagehide(instance: *runtime.Instance, value: EventHandler) anyerror!void {
    if (comptime @hasDecl(WindowEventHandlersImpl, "set_onpagehide")) return try WindowEventHandlersImpl.set_onpagehide(instance, value);
    try event_handlers.setValue(EventHandler, instance, "onpagehide", value);
}

pub fn get_onpagereveal(instance: *runtime.Instance) anyerror!EventHandler {
    if (comptime @hasDecl(WindowEventHandlersImpl, "get_onpagereveal")) return try WindowEventHandlersImpl.get_onpagereveal(instance);
    return event_handlers.value(EventHandler, instance, "onpagereveal");
}

pub fn set_onpagereveal(instance: *runtime.Instance, value: EventHandler) anyerror!void {
    if (comptime @hasDecl(WindowEventHandlersImpl, "set_onpagereveal")) return try WindowEventHandlersImpl.set_onpagereveal(instance, value);
    try event_handlers.setValue(EventHandler, instance, "onpagereveal", value);
}

pub fn get_onpageshow(instance: *runtime.Instance) anyerror!EventHandler {
    if (comptime @hasDecl(WindowEventHandlersImpl, "get_onpageshow")) return try WindowEventHandlersImpl.get_onpageshow(instance);
    return event_handlers.value(EventHandler, instance, "onpageshow");
}

pub fn set_onpageshow(instance: *runtime.Instance, value: EventHandler) anyerror!void {
    if (comptime @hasDecl(WindowEventHandlersImpl, "set_onpageshow")) return try WindowEventHandlersImpl.set_onpageshow(instance, value);
    try event_handlers.setValue(EventHandler, instance, "onpageshow", value);
}

pub fn get_onpageswap(instance: *runtime.Instance) anyerror!EventHandler {
    if (comptime @hasDecl(WindowEventHandlersImpl, "get_onpageswap")) return try WindowEventHandlersImpl.get_onpageswap(instance);
    return event_handlers.value(EventHandler, instance, "onpageswap");
}

pub fn set_onpageswap(instance: *runtime.Instance, value: EventHandler) anyerror!void {
    if (comptime @hasDecl(WindowEventHandlersImpl, "set_onpageswap")) return try WindowEventHandlersImpl.set_onpageswap(instance, value);
    try event_handlers.setValue(EventHandler, instance, "onpageswap", value);
}

pub fn get_onpopstate(instance: *runtime.Instance) anyerror!EventHandler {
    if (comptime @hasDecl(WindowEventHandlersImpl, "get_onpopstate")) return try WindowEventHandlersImpl.get_onpopstate(instance);
    return event_handlers.value(EventHandler, instance, "onpopstate");
}

pub fn set_onpopstate(instance: *runtime.Instance, value: EventHandler) anyerror!void {
    if (comptime @hasDecl(WindowEventHandlersImpl, "set_onpopstate")) return try WindowEventHandlersImpl.set_onpopstate(instance, value);
    try event_handlers.setValue(EventHandler, instance, "onpopstate", value);
}

pub fn get_onrejectionhandled(instance: *runtime.Instance) anyerror!EventHandler {
    if (comptime @hasDecl(WindowEventHandlersImpl, "get_onrejectionhandled")) return try WindowEventHandlersImpl.get_onrejectionhandled(instance);
    return event_handlers.value(EventHandler, instance, "onrejectionhandled");
}

pub fn set_onrejectionhandled(instance: *runtime.Instance, value: EventHandler) anyerror!void {
    if (comptime @hasDecl(WindowEventHandlersImpl, "set_onrejectionhandled")) return try WindowEventHandlersImpl.set_onrejectionhandled(instance, value);
    try event_handlers.setValue(EventHandler, instance, "onrejectionhandled", value);
}

pub fn get_onstorage(instance: *runtime.Instance) anyerror!EventHandler {
    if (comptime @hasDecl(WindowEventHandlersImpl, "get_onstorage")) return try WindowEventHandlersImpl.get_onstorage(instance);
    return event_handlers.value(EventHandler, instance, "onstorage");
}

pub fn set_onstorage(instance: *runtime.Instance, value: EventHandler) anyerror!void {
    if (comptime @hasDecl(WindowEventHandlersImpl, "set_onstorage")) return try WindowEventHandlersImpl.set_onstorage(instance, value);
    try event_handlers.setValue(EventHandler, instance, "onstorage", value);
}

pub fn get_onunhandledrejection(instance: *runtime.Instance) anyerror!EventHandler {
    if (comptime @hasDecl(WindowEventHandlersImpl, "get_onunhandledrejection")) return try WindowEventHandlersImpl.get_onunhandledrejection(instance);
    return event_handlers.value(EventHandler, instance, "onunhandledrejection");
}

pub fn set_onunhandledrejection(instance: *runtime.Instance, value: EventHandler) anyerror!void {
    if (comptime @hasDecl(WindowEventHandlersImpl, "set_onunhandledrejection")) return try WindowEventHandlersImpl.set_onunhandledrejection(instance, value);
    try event_handlers.setValue(EventHandler, instance, "onunhandledrejection", value);
}

pub fn get_onunload(instance: *runtime.Instance) anyerror!EventHandler {
    if (comptime @hasDecl(WindowEventHandlersImpl, "get_onunload")) return try WindowEventHandlersImpl.get_onunload(instance);
    return event_handlers.value(EventHandler, instance, "onunload");
}

pub fn set_onunload(instance: *runtime.Instance, value: EventHandler) anyerror!void {
    if (comptime @hasDecl(WindowEventHandlersImpl, "set_onunload")) return try WindowEventHandlersImpl.set_onunload(instance, value);
    try event_handlers.setValue(EventHandler, instance, "onunload", value);
}

pub fn get_ongamepadconnected(instance: *runtime.Instance) anyerror!EventHandler {
    if (comptime @hasDecl(WindowEventHandlersImpl, "get_ongamepadconnected")) return try WindowEventHandlersImpl.get_ongamepadconnected(instance);
    return event_handlers.value(EventHandler, instance, "ongamepadconnected");
}

pub fn set_ongamepadconnected(instance: *runtime.Instance, value: EventHandler) anyerror!void {
    if (comptime @hasDecl(WindowEventHandlersImpl, "set_ongamepadconnected")) return try WindowEventHandlersImpl.set_ongamepadconnected(instance, value);
    try event_handlers.setValue(EventHandler, instance, "ongamepadconnected", value);
}

pub fn get_ongamepaddisconnected(instance: *runtime.Instance) anyerror!EventHandler {
    if (comptime @hasDecl(WindowEventHandlersImpl, "get_ongamepaddisconnected")) return try WindowEventHandlersImpl.get_ongamepaddisconnected(instance);
    return event_handlers.value(EventHandler, instance, "ongamepaddisconnected");
}

pub fn set_ongamepaddisconnected(instance: *runtime.Instance, value: EventHandler) anyerror!void {
    if (comptime @hasDecl(WindowEventHandlersImpl, "set_ongamepaddisconnected")) return try WindowEventHandlersImpl.set_ongamepaddisconnected(instance, value);
    try event_handlers.setValue(EventHandler, instance, "ongamepaddisconnected", value);
}

pub fn get_onportalactivate(instance: *runtime.Instance) anyerror!EventHandler {
    if (comptime @hasDecl(WindowEventHandlersImpl, "get_onportalactivate")) return try WindowEventHandlersImpl.get_onportalactivate(instance);
    return event_handlers.value(EventHandler, instance, "onportalactivate");
}

pub fn set_onportalactivate(instance: *runtime.Instance, value: EventHandler) anyerror!void {
    if (comptime @hasDecl(WindowEventHandlersImpl, "set_onportalactivate")) return try WindowEventHandlersImpl.set_onportalactivate(instance, value);
    try event_handlers.setValue(EventHandler, instance, "onportalactivate", value);
}

/// Nullable callback attributes with [LegacyTreatNonObjectAsNull].
pub const legacy_treat_non_object_as_null = .{ "set_onafterprint", "set_onbeforeprint", "set_onbeforeunload", "set_onhashchange", "set_onlanguagechange", "set_onmessage", "set_onmessageerror", "set_onoffline", "set_ononline", "set_onpagehide", "set_onpagereveal", "set_onpageshow", "set_onpageswap", "set_onpopstate", "set_onrejectionhandled", "set_onstorage", "set_onunhandledrejection", "set_onunload", "set_ongamepadconnected", "set_ongamepaddisconnected", "set_onportalactivate" };
