//! Auto-generated mixin: NavigatorAutomationInformation
//! Its members' delegates to the mixin's impl, which every interface that
//! includes it inherits by alias.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const NavigatorAutomationInformationImpl = @import("impls").NavigatorAutomationInformation;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");

pub const impl = @import("impls").NavigatorAutomationInformation;

pub fn get_webdriver(instance: *runtime.Instance) anyerror!bool {
    return try NavigatorAutomationInformationImpl.get_webdriver(instance);
}
