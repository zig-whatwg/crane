//! Auto-generated mixin: WindowEventHandlers
//! Delegates to impl for actual implementation.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const WindowEventHandlersImpl = @import("impls").WindowEventHandlers;

// Re-export types from impl
pub const impl = @import("impls").WindowEventHandlers;

pub fn get_onafterprint(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return WindowEventHandlersImpl.get_onafterprint(instance);
}

pub fn set_onafterprint(instance: *runtime.Instance, value: typedefs.EventHandler) !void {
    return WindowEventHandlersImpl.set_onafterprint(instance, value);
}

pub fn get_onbeforeprint(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return WindowEventHandlersImpl.get_onbeforeprint(instance);
}

pub fn set_onbeforeprint(instance: *runtime.Instance, value: typedefs.EventHandler) !void {
    return WindowEventHandlersImpl.set_onbeforeprint(instance, value);
}

pub fn get_onbeforeunload(instance: *runtime.Instance) anyerror!typedefs.OnBeforeUnloadEventHandler {
    return WindowEventHandlersImpl.get_onbeforeunload(instance);
}

pub fn set_onbeforeunload(instance: *runtime.Instance, value: typedefs.OnBeforeUnloadEventHandler) !void {
    return WindowEventHandlersImpl.set_onbeforeunload(instance, value);
}

pub fn get_onhashchange(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return WindowEventHandlersImpl.get_onhashchange(instance);
}

pub fn set_onhashchange(instance: *runtime.Instance, value: typedefs.EventHandler) !void {
    return WindowEventHandlersImpl.set_onhashchange(instance, value);
}

pub fn get_onlanguagechange(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return WindowEventHandlersImpl.get_onlanguagechange(instance);
}

pub fn set_onlanguagechange(instance: *runtime.Instance, value: typedefs.EventHandler) !void {
    return WindowEventHandlersImpl.set_onlanguagechange(instance, value);
}

pub fn get_onmessage(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return WindowEventHandlersImpl.get_onmessage(instance);
}

pub fn set_onmessage(instance: *runtime.Instance, value: typedefs.EventHandler) !void {
    return WindowEventHandlersImpl.set_onmessage(instance, value);
}

pub fn get_onmessageerror(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return WindowEventHandlersImpl.get_onmessageerror(instance);
}

pub fn set_onmessageerror(instance: *runtime.Instance, value: typedefs.EventHandler) !void {
    return WindowEventHandlersImpl.set_onmessageerror(instance, value);
}

pub fn get_onoffline(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return WindowEventHandlersImpl.get_onoffline(instance);
}

pub fn set_onoffline(instance: *runtime.Instance, value: typedefs.EventHandler) !void {
    return WindowEventHandlersImpl.set_onoffline(instance, value);
}

pub fn get_ononline(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return WindowEventHandlersImpl.get_ononline(instance);
}

pub fn set_ononline(instance: *runtime.Instance, value: typedefs.EventHandler) !void {
    return WindowEventHandlersImpl.set_ononline(instance, value);
}

pub fn get_onpagehide(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return WindowEventHandlersImpl.get_onpagehide(instance);
}

pub fn set_onpagehide(instance: *runtime.Instance, value: typedefs.EventHandler) !void {
    return WindowEventHandlersImpl.set_onpagehide(instance, value);
}

pub fn get_onpagereveal(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return WindowEventHandlersImpl.get_onpagereveal(instance);
}

pub fn set_onpagereveal(instance: *runtime.Instance, value: typedefs.EventHandler) !void {
    return WindowEventHandlersImpl.set_onpagereveal(instance, value);
}

pub fn get_onpageshow(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return WindowEventHandlersImpl.get_onpageshow(instance);
}

pub fn set_onpageshow(instance: *runtime.Instance, value: typedefs.EventHandler) !void {
    return WindowEventHandlersImpl.set_onpageshow(instance, value);
}

pub fn get_onpageswap(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return WindowEventHandlersImpl.get_onpageswap(instance);
}

pub fn set_onpageswap(instance: *runtime.Instance, value: typedefs.EventHandler) !void {
    return WindowEventHandlersImpl.set_onpageswap(instance, value);
}

pub fn get_onpopstate(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return WindowEventHandlersImpl.get_onpopstate(instance);
}

pub fn set_onpopstate(instance: *runtime.Instance, value: typedefs.EventHandler) !void {
    return WindowEventHandlersImpl.set_onpopstate(instance, value);
}

pub fn get_onrejectionhandled(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return WindowEventHandlersImpl.get_onrejectionhandled(instance);
}

pub fn set_onrejectionhandled(instance: *runtime.Instance, value: typedefs.EventHandler) !void {
    return WindowEventHandlersImpl.set_onrejectionhandled(instance, value);
}

pub fn get_onstorage(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return WindowEventHandlersImpl.get_onstorage(instance);
}

pub fn set_onstorage(instance: *runtime.Instance, value: typedefs.EventHandler) !void {
    return WindowEventHandlersImpl.set_onstorage(instance, value);
}

pub fn get_onunhandledrejection(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return WindowEventHandlersImpl.get_onunhandledrejection(instance);
}

pub fn set_onunhandledrejection(instance: *runtime.Instance, value: typedefs.EventHandler) !void {
    return WindowEventHandlersImpl.set_onunhandledrejection(instance, value);
}

pub fn get_onunload(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return WindowEventHandlersImpl.get_onunload(instance);
}

pub fn set_onunload(instance: *runtime.Instance, value: typedefs.EventHandler) !void {
    return WindowEventHandlersImpl.set_onunload(instance, value);
}

pub fn get_ongamepadconnected(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return WindowEventHandlersImpl.get_ongamepadconnected(instance);
}

pub fn set_ongamepadconnected(instance: *runtime.Instance, value: typedefs.EventHandler) !void {
    return WindowEventHandlersImpl.set_ongamepadconnected(instance, value);
}

pub fn get_ongamepaddisconnected(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return WindowEventHandlersImpl.get_ongamepaddisconnected(instance);
}

pub fn set_ongamepaddisconnected(instance: *runtime.Instance, value: typedefs.EventHandler) !void {
    return WindowEventHandlersImpl.set_ongamepaddisconnected(instance, value);
}

pub fn get_onportalactivate(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return WindowEventHandlersImpl.get_onportalactivate(instance);
}

pub fn set_onportalactivate(instance: *runtime.Instance, value: typedefs.EventHandler) !void {
    return WindowEventHandlersImpl.set_onportalactivate(instance, value);
}

