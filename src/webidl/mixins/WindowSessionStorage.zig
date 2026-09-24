//! Auto-generated mixin: WindowSessionStorage
//! Its members' delegates to the mixin's impl, which every interface that
//! includes it inherits by alias.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const WindowSessionStorageImpl = @import("impls").WindowSessionStorage;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const Storage = @import("interfaces").Storage;

pub const impl = @import("impls").WindowSessionStorage;

pub fn get_sessionStorage(instance: *runtime.Instance) anyerror!*runtime.Instance {
    return try WindowSessionStorageImpl.get_sessionStorage(instance);
}
