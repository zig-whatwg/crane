//! Auto-generated mixin: NavigatorID
//! Its members' delegates to the mixin's impl, which every interface that
//! includes it inherits by alias.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const NavigatorIDImpl = @import("impls").NavigatorID;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const DOMString = @import("typedefs").DOMString;

pub const impl = @import("impls").NavigatorID;

pub fn get_appCodeName(instance: *runtime.Instance) anyerror!DOMString {
    return try NavigatorIDImpl.get_appCodeName(instance);
}

pub fn get_appName(instance: *runtime.Instance) anyerror!DOMString {
    return try NavigatorIDImpl.get_appName(instance);
}

pub fn get_appVersion(instance: *runtime.Instance) anyerror!DOMString {
    return try NavigatorIDImpl.get_appVersion(instance);
}

pub fn get_platform(instance: *runtime.Instance) anyerror!DOMString {
    return try NavigatorIDImpl.get_platform(instance);
}

pub fn get_product(instance: *runtime.Instance) anyerror!DOMString {
    return try NavigatorIDImpl.get_product(instance);
}

/// Extended attributes: [Exposed=Window]
pub fn get_productSub(instance: *runtime.Instance) anyerror!DOMString {
    return try NavigatorIDImpl.get_productSub(instance);
}

pub fn get_userAgent(instance: *runtime.Instance) anyerror!DOMString {
    return try NavigatorIDImpl.get_userAgent(instance);
}

/// Extended attributes: [Exposed=Window]
pub fn get_vendor(instance: *runtime.Instance) anyerror!DOMString {
    return try NavigatorIDImpl.get_vendor(instance);
}

/// Extended attributes: [Exposed=Window]
pub fn get_vendorSub(instance: *runtime.Instance) anyerror!DOMString {
    return try NavigatorIDImpl.get_vendorSub(instance);
}

/// Extended attributes: [Exposed=Window]
pub fn get_oscpu(instance: *runtime.Instance) anyerror!DOMString {
    return try NavigatorIDImpl.get_oscpu(instance);
}

/// Extended attributes: [Exposed=Window]
pub fn call_taintEnabled(instance: *runtime.Instance) anyerror!bool {
    return try NavigatorIDImpl.call_taintEnabled(instance);
}
