//! Auto-generated mixin: CanvasTransform
//! Its members' delegates to the mixin's impl, which every interface that
//! includes it inherits by alias.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const CanvasTransformImpl = @import("impls").CanvasTransform;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const DOMMatrix2DInit = @import("dictionaries").DOMMatrix2DInit;
const DOMMatrix = @import("interfaces").DOMMatrix;

pub const impl = @import("impls").CanvasTransform;

pub fn call_rotate(instance: *runtime.Instance, angle: f64) anyerror!void {
    return try CanvasTransformImpl.call_rotate(instance, angle);
}

pub fn call_scale(instance: *runtime.Instance, x: f64, y: f64) anyerror!void {
    return try CanvasTransformImpl.call_scale(instance, x, y);
}

pub fn call_translate(instance: *runtime.Instance, x: f64, y: f64) anyerror!void {
    return try CanvasTransformImpl.call_translate(instance, x, y);
}

pub fn call_resetTransform(instance: *runtime.Instance) anyerror!void {
    return try CanvasTransformImpl.call_resetTransform(instance);
}

pub fn call_transform(instance: *runtime.Instance, a: f64, b: f64, c: f64, d: f64, e: f64, f: f64) anyerror!void {
    return try CanvasTransformImpl.call_transform(instance, a, b, c, d, e, f);
}

/// Extended attributes: [NewObject]
pub fn call_getTransform(instance: *runtime.Instance) anyerror!*runtime.Instance {
    // [NewObject] - Caller owns the returned object
    return try CanvasTransformImpl.call_getTransform(instance);
}

pub fn call_setTransform(instance: *runtime.Instance, a: f64, b: f64, c: f64, d: f64, e: f64, f: f64) anyerror!void {
    return try CanvasTransformImpl.call_setTransform(instance, a, b, c, d, e, f);
}

pub fn call_setTransform__1(instance: *runtime.Instance, transform: webidl.Opt(DOMMatrix2DInit)) anyerror!void {
    if (comptime @hasDecl(CanvasTransformImpl, "call_setTransform__1")) {
        return try CanvasTransformImpl.call_setTransform__1(instance, transform);
    } else {
        return error.NotImplemented;
    }
}

/// WebIDL overload sets: every overload of each overloaded operation,
/// in IDL order, for the overload resolution algorithm
/// (webidl.overload_resolution). The binding is installed for the first
/// overload and forwards to the one the arguments select.
pub const overloads = .{
    .{ "setTransform", &[_]webidl.overload_resolution.Overload{
        .{ .function = "call_setTransform", .args = &.{ .{ .kinds = &.{.numeric} }, .{ .kinds = &.{.numeric} }, .{ .kinds = &.{.numeric} }, .{ .kinds = &.{.numeric} }, .{ .kinds = &.{.numeric} }, .{ .kinds = &.{.numeric} } } },
        .{ .function = "call_setTransform__1", .implemented = @hasDecl(CanvasTransformImpl, "call_setTransform__1"), .args = &.{.{ .kinds = &.{.dictionary}, .optionality = .optional }} },
    } },
};
