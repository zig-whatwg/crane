//! Auto-generated mixin: GlobalPrivacyControl
//! Delegates to impl for actual implementation.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const GlobalPrivacyControlImpl = @import("impls").GlobalPrivacyControl;

// Re-export types from impl
pub const impl = @import("impls").GlobalPrivacyControl;

pub fn get_globalPrivacyControl(instance: *runtime.Instance) anyerror!bool {
    return GlobalPrivacyControlImpl.get_globalPrivacyControl(instance);
}

