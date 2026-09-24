//! Auto-generated mixin: HTMLSharedStorageWritableElementUtils
//! Its members' delegates to the mixin's impl, which every interface that
//! includes it inherits by alias.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const HTMLSharedStorageWritableElementUtilsImpl = @import("impls").HTMLSharedStorageWritableElementUtils;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");

pub const impl = @import("impls").HTMLSharedStorageWritableElementUtils;

/// Extended attributes: [CEReactions], [SecureContext]
pub fn get_sharedStorageWritable(instance: *runtime.Instance) anyerror!bool {
    return try HTMLSharedStorageWritableElementUtilsImpl.get_sharedStorageWritable(instance);
}

/// Extended attributes: [CEReactions], [SecureContext]
pub fn set_sharedStorageWritable(instance: *runtime.Instance, value: bool) anyerror!void {
    // [CEReactions] - Trigger Custom Element lifecycle callbacks
    runtime.CEReactions.begin();
    defer runtime.CEReactions.end();

    try HTMLSharedStorageWritableElementUtilsImpl.set_sharedStorageWritable(instance, value);
}
