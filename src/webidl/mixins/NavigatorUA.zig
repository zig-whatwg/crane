//! Auto-generated mixin: NavigatorUA
//! Its members' delegates to the mixin's impl, which every interface that
//! includes it inherits by alias.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const NavigatorUAImpl = @import("impls").NavigatorUA;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const NavigatorUAData = @import("interfaces").NavigatorUAData;

pub const impl = @import("impls").NavigatorUA;

/// Extended attributes: [SecureContext]
pub fn get_userAgentData(instance: *runtime.Instance) anyerror!*runtime.Instance {
    return try NavigatorUAImpl.get_userAgentData(instance);
}
