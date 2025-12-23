//! Auto-generated mixin: NavigatorNetworkInformation
//! Delegates to impl for actual implementation.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const NavigatorNetworkInformationImpl = @import("impls").NavigatorNetworkInformation;

// Re-export types from impl
pub const impl = @import("impls").NavigatorNetworkInformation;

pub fn get_connection(instance: *runtime.Instance) !*runtime.Instance {
    return NavigatorNetworkInformationImpl.get_connection(instance);
}

