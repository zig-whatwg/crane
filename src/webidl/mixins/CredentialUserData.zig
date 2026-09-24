//! Auto-generated mixin: CredentialUserData
//! Its members' delegates to the mixin's impl, which every interface that
//! includes it inherits by alias.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const CredentialUserDataImpl = @import("impls").CredentialUserData;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const USVString = @import("typedefs").USVString;

pub const impl = @import("impls").CredentialUserData;

pub fn get_name(instance: *runtime.Instance) anyerror!runtime.USVString {
    return try CredentialUserDataImpl.get_name(instance);
}

pub fn get_iconURL(instance: *runtime.Instance) anyerror!runtime.USVString {
    return try CredentialUserDataImpl.get_iconURL(instance);
}
