//! Auto-generated mixin: CredentialUserData
//! Delegates to impl for actual implementation.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const CredentialUserDataImpl = @import("impls").CredentialUserData;

// Re-export types from impl
pub const impl = @import("impls").CredentialUserData;

pub fn get_name(instance: *runtime.Instance) anyerror!runtime.USVString {
    return CredentialUserDataImpl.get_name(instance);
}

pub fn get_iconURL(instance: *runtime.Instance) anyerror!runtime.USVString {
    return CredentialUserDataImpl.get_iconURL(instance);
}

