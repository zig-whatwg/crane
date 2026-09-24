//! Auto-generated mixin: PushManagerAttribute
//! Its members' delegates to the mixin's impl, which every interface that
//! includes it inherits by alias.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const PushManagerAttributeImpl = @import("impls").PushManagerAttribute;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const PushManager = @import("interfaces").PushManager;

pub const impl = @import("impls").PushManagerAttribute;

pub fn get_pushManager(instance: *runtime.Instance) anyerror!*runtime.Instance {
    return try PushManagerAttributeImpl.get_pushManager(instance);
}
