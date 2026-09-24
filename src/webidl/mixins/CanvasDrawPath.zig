//! Auto-generated mixin: CanvasDrawPath
//! Its members' delegates to the mixin's impl, which every interface that
//! includes it inherits by alias.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const CanvasDrawPathImpl = @import("impls").CanvasDrawPath;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const CanvasFillRule = @import("enums").CanvasFillRule;
const Path2D = @import("interfaces").Path2D;

pub const impl = @import("impls").CanvasDrawPath;

pub fn call_clip(instance: *runtime.Instance, fillRule: webidl.Opt(CanvasFillRule)) anyerror!void {
    return try CanvasDrawPathImpl.call_clip(instance, fillRule);
}

pub fn call_isPointInStroke(instance: *runtime.Instance, x: f64, y: f64) anyerror!bool {
    return try CanvasDrawPathImpl.call_isPointInStroke(instance, x, y);
}

pub fn call_beginPath(instance: *runtime.Instance) anyerror!void {
    return try CanvasDrawPathImpl.call_beginPath(instance);
}

pub fn call_isPointInPath(instance: *runtime.Instance, x: f64, y: f64, fillRule: webidl.Opt(CanvasFillRule)) anyerror!bool {
    return try CanvasDrawPathImpl.call_isPointInPath(instance, x, y, fillRule);
}

pub fn call_fill(instance: *runtime.Instance, fillRule: webidl.Opt(CanvasFillRule)) anyerror!void {
    return try CanvasDrawPathImpl.call_fill(instance, fillRule);
}

pub fn call_stroke(instance: *runtime.Instance) anyerror!void {
    return try CanvasDrawPathImpl.call_stroke(instance);
}

pub fn call_isPointInPath__1(instance: *runtime.Instance, path: *runtime.Instance, x: f64, y: f64, fillRule: webidl.Opt(CanvasFillRule)) anyerror!bool {
    if (comptime @hasDecl(CanvasDrawPathImpl, "call_isPointInPath__1")) {
        return try CanvasDrawPathImpl.call_isPointInPath__1(instance, path, x, y, fillRule);
    } else {
        return error.NotImplemented;
    }
}

pub fn call_stroke__1(instance: *runtime.Instance, path: *runtime.Instance) anyerror!void {
    if (comptime @hasDecl(CanvasDrawPathImpl, "call_stroke__1")) {
        return try CanvasDrawPathImpl.call_stroke__1(instance, path);
    } else {
        return error.NotImplemented;
    }
}

pub fn call_isPointInStroke__1(instance: *runtime.Instance, path: *runtime.Instance, x: f64, y: f64) anyerror!bool {
    if (comptime @hasDecl(CanvasDrawPathImpl, "call_isPointInStroke__1")) {
        return try CanvasDrawPathImpl.call_isPointInStroke__1(instance, path, x, y);
    } else {
        return error.NotImplemented;
    }
}

pub fn call_fill__1(instance: *runtime.Instance, path: *runtime.Instance, fillRule: webidl.Opt(CanvasFillRule)) anyerror!void {
    if (comptime @hasDecl(CanvasDrawPathImpl, "call_fill__1")) {
        return try CanvasDrawPathImpl.call_fill__1(instance, path, fillRule);
    } else {
        return error.NotImplemented;
    }
}

pub fn call_clip__1(instance: *runtime.Instance, path: *runtime.Instance, fillRule: webidl.Opt(CanvasFillRule)) anyerror!void {
    if (comptime @hasDecl(CanvasDrawPathImpl, "call_clip__1")) {
        return try CanvasDrawPathImpl.call_clip__1(instance, path, fillRule);
    } else {
        return error.NotImplemented;
    }
}

/// WebIDL overload sets: every overload of each overloaded operation,
/// in IDL order, for the overload resolution algorithm
/// (webidl.overload_resolution). The binding is installed for the first
/// overload and forwards to the one the arguments select.
pub const overloads = .{
    .{ "isPointInPath", &[_]webidl.overload_resolution.Overload{
        .{ .function = "call_isPointInPath", .args = &.{ .{ .kinds = &.{.numeric} }, .{ .kinds = &.{.numeric} }, .{ .kinds = &.{.string}, .optionality = .optional } } },
        .{ .function = "call_isPointInPath__1", .implemented = @hasDecl(CanvasDrawPathImpl, "call_isPointInPath__1"), .args = &.{ .{ .kinds = &.{(if (@hasDecl(@import("interfaces"), "Path2D")) webidl.overload_resolution.Kind{ .interface = runtime.typeId(@import("interfaces").Path2D.State) } else .other)} }, .{ .kinds = &.{.numeric} }, .{ .kinds = &.{.numeric} }, .{ .kinds = &.{.string}, .optionality = .optional } } },
    } },
    .{ "stroke", &[_]webidl.overload_resolution.Overload{
        .{ .function = "call_stroke", .args = &.{} },
        .{ .function = "call_stroke__1", .implemented = @hasDecl(CanvasDrawPathImpl, "call_stroke__1"), .args = &.{.{ .kinds = &.{(if (@hasDecl(@import("interfaces"), "Path2D")) webidl.overload_resolution.Kind{ .interface = runtime.typeId(@import("interfaces").Path2D.State) } else .other)} }} },
    } },
    .{ "isPointInStroke", &[_]webidl.overload_resolution.Overload{
        .{ .function = "call_isPointInStroke", .args = &.{ .{ .kinds = &.{.numeric} }, .{ .kinds = &.{.numeric} } } },
        .{ .function = "call_isPointInStroke__1", .implemented = @hasDecl(CanvasDrawPathImpl, "call_isPointInStroke__1"), .args = &.{ .{ .kinds = &.{(if (@hasDecl(@import("interfaces"), "Path2D")) webidl.overload_resolution.Kind{ .interface = runtime.typeId(@import("interfaces").Path2D.State) } else .other)} }, .{ .kinds = &.{.numeric} }, .{ .kinds = &.{.numeric} } } },
    } },
    .{ "fill", &[_]webidl.overload_resolution.Overload{
        .{ .function = "call_fill", .args = &.{.{ .kinds = &.{.string}, .optionality = .optional }} },
        .{ .function = "call_fill__1", .implemented = @hasDecl(CanvasDrawPathImpl, "call_fill__1"), .args = &.{ .{ .kinds = &.{(if (@hasDecl(@import("interfaces"), "Path2D")) webidl.overload_resolution.Kind{ .interface = runtime.typeId(@import("interfaces").Path2D.State) } else .other)} }, .{ .kinds = &.{.string}, .optionality = .optional } } },
    } },
    .{ "clip", &[_]webidl.overload_resolution.Overload{
        .{ .function = "call_clip", .args = &.{.{ .kinds = &.{.string}, .optionality = .optional }} },
        .{ .function = "call_clip__1", .implemented = @hasDecl(CanvasDrawPathImpl, "call_clip__1"), .args = &.{ .{ .kinds = &.{(if (@hasDecl(@import("interfaces"), "Path2D")) webidl.overload_resolution.Kind{ .interface = runtime.typeId(@import("interfaces").Path2D.State) } else .other)} }, .{ .kinds = &.{.string}, .optionality = .optional } } },
    } },
};
