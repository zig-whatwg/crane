//! Auto-generated mixin: HTMLSharedStorageWritableElementUtils
//! Delegates to impl for actual implementation.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const HTMLSharedStorageWritableElementUtilsImpl = @import("impls").HTMLSharedStorageWritableElementUtils;

// Re-export types from impl
pub const impl = @import("impls").HTMLSharedStorageWritableElementUtils;

pub fn get_sharedStorageWritable(instance: *runtime.Instance) anyerror!bool {
    return HTMLSharedStorageWritableElementUtilsImpl.get_sharedStorageWritable(instance);
}

pub fn set_sharedStorageWritable(instance: *runtime.Instance, value: runtime.JSValue) !void {
    return HTMLSharedStorageWritableElementUtilsImpl.set_sharedStorageWritable(instance, value);
}

