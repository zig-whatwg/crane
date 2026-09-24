//! Auto-generated mixin: CanvasDrawImage
//! Its members' delegates to the mixin's impl, which every interface that
//! includes it inherits by alias.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const CanvasDrawImageImpl = @import("impls").CanvasDrawImage;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const CanvasImageSource = @import("typedefs").CanvasImageSource;

pub const impl = @import("impls").CanvasDrawImage;

pub fn call_drawImage(instance: *runtime.Instance, image: CanvasImageSource, dx: f64, dy: f64) anyerror!void {
    return try CanvasDrawImageImpl.call_drawImage(instance, image, dx, dy);
}

pub fn call_drawImage__1(instance: *runtime.Instance, image: CanvasImageSource, dx: f64, dy: f64, dw: f64, dh: f64) anyerror!void {
    if (comptime @hasDecl(CanvasDrawImageImpl, "call_drawImage__1")) {
        return try CanvasDrawImageImpl.call_drawImage__1(instance, image, dx, dy, dw, dh);
    } else {
        return error.NotImplemented;
    }
}

pub fn call_drawImage__2(instance: *runtime.Instance, image: CanvasImageSource, sx: f64, sy: f64, sw: f64, sh: f64, dx: f64, dy: f64, dw: f64, dh: f64) anyerror!void {
    if (comptime @hasDecl(CanvasDrawImageImpl, "call_drawImage__2")) {
        return try CanvasDrawImageImpl.call_drawImage__2(instance, image, sx, sy, sw, sh, dx, dy, dw, dh);
    } else {
        return error.NotImplemented;
    }
}

/// WebIDL overload sets: every overload of each overloaded operation,
/// in IDL order, for the overload resolution algorithm
/// (webidl.overload_resolution). The binding is installed for the first
/// overload and forwards to the one the arguments select.
pub const overloads = .{
    .{ "drawImage", &[_]webidl.overload_resolution.Overload{
        .{ .function = "call_drawImage", .args = &.{ .{ .kinds = &.{.other} }, .{ .kinds = &.{.numeric} }, .{ .kinds = &.{.numeric} } } },
        .{ .function = "call_drawImage__1", .implemented = @hasDecl(CanvasDrawImageImpl, "call_drawImage__1"), .args = &.{ .{ .kinds = &.{.other} }, .{ .kinds = &.{.numeric} }, .{ .kinds = &.{.numeric} }, .{ .kinds = &.{.numeric} }, .{ .kinds = &.{.numeric} } } },
        .{ .function = "call_drawImage__2", .implemented = @hasDecl(CanvasDrawImageImpl, "call_drawImage__2"), .args = &.{ .{ .kinds = &.{.other} }, .{ .kinds = &.{.numeric} }, .{ .kinds = &.{.numeric} }, .{ .kinds = &.{.numeric} }, .{ .kinds = &.{.numeric} }, .{ .kinds = &.{.numeric} }, .{ .kinds = &.{.numeric} }, .{ .kinds = &.{.numeric} }, .{ .kinds = &.{.numeric} } } },
    } },
};
