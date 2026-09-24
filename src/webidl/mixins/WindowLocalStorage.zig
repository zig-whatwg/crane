//! Auto-generated mixin: WindowLocalStorage
//! Its members' delegates to the mixin's impl, which every interface that
//! includes it inherits by alias.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const WindowLocalStorageImpl = @import("impls").WindowLocalStorage;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const Storage = @import("interfaces").Storage;

pub const impl = @import("impls").WindowLocalStorage;

pub fn get_localStorage(instance: *runtime.Instance) anyerror!*runtime.Instance {
    return try WindowLocalStorageImpl.get_localStorage(instance);
}
