//! Auto-generated mixin: Body
//! Delegates to impl for actual implementation.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const BodyImpl = @import("impls").Body;

// Re-export types from impl
pub const impl = @import("impls").Body;

pub fn get_body(instance: *runtime.Instance) !?*runtime.Instance {
    return BodyImpl.get_body(instance);
}

pub fn get_bodyUsed(instance: *runtime.Instance) anyerror!bool {
    return BodyImpl.get_bodyUsed(instance);
}

pub fn call_arrayBuffer(instance: *runtime.Instance) anyerror!void {
    return BodyImpl.call_arrayBuffer(instance);
}

pub fn call_bytes(instance: *runtime.Instance) anyerror!void {
    return BodyImpl.call_bytes(instance);
}

pub fn call_json(instance: *runtime.Instance) anyerror!void {
    return BodyImpl.call_json(instance);
}

pub fn call_formData(instance: *runtime.Instance) anyerror!void {
    return BodyImpl.call_formData(instance);
}

pub fn call_text(instance: *runtime.Instance) anyerror!void {
    return BodyImpl.call_text(instance);
}

pub fn call_blob(instance: *runtime.Instance) anyerror!void {
    return BodyImpl.call_blob(instance);
}

