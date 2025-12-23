//! Auto-generated mixin: HTMLHyperlinkElementUtils
//! Delegates to impl for actual implementation.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const HTMLHyperlinkElementUtilsImpl = @import("impls").HTMLHyperlinkElementUtils;

// Re-export types from impl
pub const impl = @import("impls").HTMLHyperlinkElementUtils;

pub fn get_href(instance: *runtime.Instance) anyerror!runtime.USVString {
    return HTMLHyperlinkElementUtilsImpl.get_href(instance);
}

pub fn set_href(instance: *runtime.Instance, value: runtime.JSValue) !void {
    return HTMLHyperlinkElementUtilsImpl.set_href(instance, value);
}

pub fn get_origin(instance: *runtime.Instance) anyerror!runtime.USVString {
    return HTMLHyperlinkElementUtilsImpl.get_origin(instance);
}

pub fn get_protocol(instance: *runtime.Instance) anyerror!runtime.USVString {
    return HTMLHyperlinkElementUtilsImpl.get_protocol(instance);
}

pub fn set_protocol(instance: *runtime.Instance, value: runtime.JSValue) !void {
    return HTMLHyperlinkElementUtilsImpl.set_protocol(instance, value);
}

pub fn get_username(instance: *runtime.Instance) anyerror!runtime.USVString {
    return HTMLHyperlinkElementUtilsImpl.get_username(instance);
}

pub fn set_username(instance: *runtime.Instance, value: runtime.JSValue) !void {
    return HTMLHyperlinkElementUtilsImpl.set_username(instance, value);
}

pub fn get_password(instance: *runtime.Instance) anyerror!runtime.USVString {
    return HTMLHyperlinkElementUtilsImpl.get_password(instance);
}

pub fn set_password(instance: *runtime.Instance, value: runtime.JSValue) !void {
    return HTMLHyperlinkElementUtilsImpl.set_password(instance, value);
}

pub fn get_host(instance: *runtime.Instance) anyerror!runtime.USVString {
    return HTMLHyperlinkElementUtilsImpl.get_host(instance);
}

pub fn set_host(instance: *runtime.Instance, value: runtime.JSValue) !void {
    return HTMLHyperlinkElementUtilsImpl.set_host(instance, value);
}

pub fn get_hostname(instance: *runtime.Instance) anyerror!runtime.USVString {
    return HTMLHyperlinkElementUtilsImpl.get_hostname(instance);
}

pub fn set_hostname(instance: *runtime.Instance, value: runtime.JSValue) !void {
    return HTMLHyperlinkElementUtilsImpl.set_hostname(instance, value);
}

pub fn get_port(instance: *runtime.Instance) anyerror!runtime.USVString {
    return HTMLHyperlinkElementUtilsImpl.get_port(instance);
}

pub fn set_port(instance: *runtime.Instance, value: runtime.JSValue) !void {
    return HTMLHyperlinkElementUtilsImpl.set_port(instance, value);
}

pub fn get_pathname(instance: *runtime.Instance) anyerror!runtime.USVString {
    return HTMLHyperlinkElementUtilsImpl.get_pathname(instance);
}

pub fn set_pathname(instance: *runtime.Instance, value: runtime.JSValue) !void {
    return HTMLHyperlinkElementUtilsImpl.set_pathname(instance, value);
}

pub fn get_search(instance: *runtime.Instance) anyerror!runtime.USVString {
    return HTMLHyperlinkElementUtilsImpl.get_search(instance);
}

pub fn set_search(instance: *runtime.Instance, value: runtime.JSValue) !void {
    return HTMLHyperlinkElementUtilsImpl.set_search(instance, value);
}

pub fn get_hash(instance: *runtime.Instance) anyerror!runtime.USVString {
    return HTMLHyperlinkElementUtilsImpl.get_hash(instance);
}

pub fn set_hash(instance: *runtime.Instance, value: runtime.JSValue) !void {
    return HTMLHyperlinkElementUtilsImpl.set_hash(instance, value);
}

