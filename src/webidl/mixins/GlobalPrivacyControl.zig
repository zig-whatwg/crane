//! Auto-generated mixin: GlobalPrivacyControl
//! Its members' delegates to the mixin's impl, which every interface that
//! includes it inherits by alias.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const GlobalPrivacyControlImpl = @import("impls").GlobalPrivacyControl;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");

pub const impl = @import("impls").GlobalPrivacyControl;

pub fn get_globalPrivacyControl(instance: *runtime.Instance) anyerror!bool {
    return try GlobalPrivacyControlImpl.get_globalPrivacyControl(instance);
}
