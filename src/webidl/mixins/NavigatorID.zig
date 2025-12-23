//! Auto-generated mixin: NavigatorID
//! Delegates to impl for actual implementation.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const NavigatorIDImpl = @import("impls").NavigatorID;

// Re-export types from impl
pub const impl = @import("impls").NavigatorID;

pub fn get_appCodeName(instance: *runtime.Instance) anyerror!typedefs.DOMString {
    return NavigatorIDImpl.get_appCodeName(instance);
}

pub fn get_appName(instance: *runtime.Instance) anyerror!typedefs.DOMString {
    return NavigatorIDImpl.get_appName(instance);
}

pub fn get_appVersion(instance: *runtime.Instance) anyerror!typedefs.DOMString {
    return NavigatorIDImpl.get_appVersion(instance);
}

pub fn get_platform(instance: *runtime.Instance) anyerror!typedefs.DOMString {
    return NavigatorIDImpl.get_platform(instance);
}

pub fn get_product(instance: *runtime.Instance) anyerror!typedefs.DOMString {
    return NavigatorIDImpl.get_product(instance);
}

pub fn get_productSub(instance: *runtime.Instance) anyerror!typedefs.DOMString {
    return NavigatorIDImpl.get_productSub(instance);
}

pub fn get_userAgent(instance: *runtime.Instance) anyerror!typedefs.DOMString {
    return NavigatorIDImpl.get_userAgent(instance);
}

pub fn get_vendor(instance: *runtime.Instance) anyerror!typedefs.DOMString {
    return NavigatorIDImpl.get_vendor(instance);
}

pub fn get_vendorSub(instance: *runtime.Instance) anyerror!typedefs.DOMString {
    return NavigatorIDImpl.get_vendorSub(instance);
}

pub fn get_oscpu(instance: *runtime.Instance) anyerror!typedefs.DOMString {
    return NavigatorIDImpl.get_oscpu(instance);
}

pub fn call_taintEnabled(instance: *runtime.Instance) anyerror!bool {
    return NavigatorIDImpl.call_taintEnabled(instance);
}

