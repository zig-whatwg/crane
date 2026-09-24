//! Auto-generated mixin: NavigatorNetworkInformation
//! Its members' delegates to the mixin's impl, which every interface that
//! includes it inherits by alias.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const NavigatorNetworkInformationImpl = @import("impls").NavigatorNetworkInformation;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const NetworkInformation = @import("interfaces").NetworkInformation;

pub const impl = @import("impls").NavigatorNetworkInformation;

/// Extended attributes: [SameObject]
pub fn get_connection(instance: *runtime.Instance) anyerror!*runtime.Instance {
    return try NavigatorNetworkInformationImpl.get_connection(instance);
}
