//! Auto-generated mixin: Body
//! Its members' delegates to the mixin's impl, which every interface that
//! includes it inherits by alias.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const BodyImpl = @import("impls").Body;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const ReadableStream = @import("interfaces").ReadableStream;
const Blob = @import("interfaces").Blob;
const FormData = @import("interfaces").FormData;
const USVString = @import("typedefs").USVString;

pub const impl = @import("impls").Body;

pub fn get_body(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    return try BodyImpl.get_body(instance);
}

pub fn get_bodyUsed(instance: *runtime.Instance) anyerror!bool {
    return try BodyImpl.get_bodyUsed(instance);
}

/// Extended attributes: [NewObject]
pub fn call_arrayBuffer(instance: *runtime.Instance) anyerror!runtime.JSValue {
    // [NewObject] - Caller owns the returned object
    return try BodyImpl.call_arrayBuffer(instance);
}

/// Extended attributes: [NewObject]
pub fn call_bytes(instance: *runtime.Instance) anyerror!runtime.JSValue {
    // [NewObject] - Caller owns the returned object
    return try BodyImpl.call_bytes(instance);
}

/// Extended attributes: [NewObject]
pub fn call_json(instance: *runtime.Instance) anyerror!runtime.JSValue {
    // [NewObject] - Caller owns the returned object
    return try BodyImpl.call_json(instance);
}

/// Extended attributes: [NewObject]
pub fn call_formData(instance: *runtime.Instance) anyerror!runtime.JSValue {
    // [NewObject] - Caller owns the returned object
    return try BodyImpl.call_formData(instance);
}

/// Extended attributes: [NewObject]
pub fn call_text(instance: *runtime.Instance) anyerror!runtime.JSValue {
    // [NewObject] - Caller owns the returned object
    return try BodyImpl.call_text(instance);
}

/// Extended attributes: [NewObject]
pub fn call_blob(instance: *runtime.Instance) anyerror!runtime.JSValue {
    // [NewObject] - Caller owns the returned object
    return try BodyImpl.call_blob(instance);
}

/// WebIDL: operations whose return type is a promise - an exception in
/// their steps becomes a rejected promise.
pub const promise_returning = .{
    "call_arrayBuffer",
    "call_bytes",
    "call_json",
    "call_formData",
    "call_text",
    "call_blob",
};
