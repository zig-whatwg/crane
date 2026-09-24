//! Auto-generated mixin: CanvasImageData
//! Its members' delegates to the mixin's impl, which every interface that
//! includes it inherits by alias.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const CanvasImageDataImpl = @import("impls").CanvasImageData;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const ImageDataSettings = @import("dictionaries").ImageDataSettings;
const ImageData = @import("interfaces").ImageData;

pub const impl = @import("impls").CanvasImageData;

pub fn call_putImageData(instance: *runtime.Instance, imageData: *runtime.Instance, dx: i32, dy: i32) anyerror!void {
    // [EnforceRange] on dx
    if (!runtime.isInRange(i32, dx)) return error.TypeError;
    // [EnforceRange] on dy
    if (!runtime.isInRange(i32, dy)) return error.TypeError;

    return try CanvasImageDataImpl.call_putImageData(instance, imageData, dx, dy);
}

pub fn call_createImageData(instance: *runtime.Instance, sw: i32, sh: i32, settings: webidl.Opt(ImageDataSettings)) anyerror!*runtime.Instance {
    // [EnforceRange] on sw
    if (!runtime.isInRange(i32, sw)) return error.TypeError;
    // [EnforceRange] on sh
    if (!runtime.isInRange(i32, sh)) return error.TypeError;

    return try CanvasImageDataImpl.call_createImageData(instance, sw, sh, settings);
}

pub fn call_getImageData(instance: *runtime.Instance, sx: i32, sy: i32, sw: i32, sh: i32, settings: webidl.Opt(ImageDataSettings)) anyerror!*runtime.Instance {
    // [EnforceRange] on sx
    if (!runtime.isInRange(i32, sx)) return error.TypeError;
    // [EnforceRange] on sy
    if (!runtime.isInRange(i32, sy)) return error.TypeError;
    // [EnforceRange] on sw
    if (!runtime.isInRange(i32, sw)) return error.TypeError;
    // [EnforceRange] on sh
    if (!runtime.isInRange(i32, sh)) return error.TypeError;

    return try CanvasImageDataImpl.call_getImageData(instance, sx, sy, sw, sh, settings);
}

pub fn call_putImageData__1(instance: *runtime.Instance, imageData: *runtime.Instance, dx: i32, dy: i32, dirtyX: i32, dirtyY: i32, dirtyWidth: i32, dirtyHeight: i32) anyerror!void {
    if (comptime @hasDecl(CanvasImageDataImpl, "call_putImageData__1")) {
        // [EnforceRange] on dx
        if (!runtime.isInRange(i32, dx)) return error.TypeError;
        // [EnforceRange] on dy
        if (!runtime.isInRange(i32, dy)) return error.TypeError;
        // [EnforceRange] on dirtyX
        if (!runtime.isInRange(i32, dirtyX)) return error.TypeError;
        // [EnforceRange] on dirtyY
        if (!runtime.isInRange(i32, dirtyY)) return error.TypeError;
        // [EnforceRange] on dirtyWidth
        if (!runtime.isInRange(i32, dirtyWidth)) return error.TypeError;
        // [EnforceRange] on dirtyHeight
        if (!runtime.isInRange(i32, dirtyHeight)) return error.TypeError;

        return try CanvasImageDataImpl.call_putImageData__1(instance, imageData, dx, dy, dirtyX, dirtyY, dirtyWidth, dirtyHeight);
    } else {
        return error.NotImplemented;
    }
}

pub fn call_createImageData__1(instance: *runtime.Instance, imageData: *runtime.Instance) anyerror!*runtime.Instance {
    if (comptime @hasDecl(CanvasImageDataImpl, "call_createImageData__1")) {
        return try CanvasImageDataImpl.call_createImageData__1(instance, imageData);
    } else {
        return error.NotImplemented;
    }
}

/// WebIDL overload sets: every overload of each overloaded operation,
/// in IDL order, for the overload resolution algorithm
/// (webidl.overload_resolution). The binding is installed for the first
/// overload and forwards to the one the arguments select.
pub const overloads = .{
    .{ "putImageData", &[_]webidl.overload_resolution.Overload{
        .{ .function = "call_putImageData", .args = &.{ .{ .kinds = &.{(if (@hasDecl(@import("interfaces"), "ImageData")) webidl.overload_resolution.Kind{ .interface = runtime.typeId(@import("interfaces").ImageData.State) } else .other)} }, .{ .kinds = &.{.numeric} }, .{ .kinds = &.{.numeric} } } },
        .{ .function = "call_putImageData__1", .implemented = @hasDecl(CanvasImageDataImpl, "call_putImageData__1"), .args = &.{ .{ .kinds = &.{(if (@hasDecl(@import("interfaces"), "ImageData")) webidl.overload_resolution.Kind{ .interface = runtime.typeId(@import("interfaces").ImageData.State) } else .other)} }, .{ .kinds = &.{.numeric} }, .{ .kinds = &.{.numeric} }, .{ .kinds = &.{.numeric} }, .{ .kinds = &.{.numeric} }, .{ .kinds = &.{.numeric} }, .{ .kinds = &.{.numeric} } } },
    } },
    .{ "createImageData", &[_]webidl.overload_resolution.Overload{
        .{ .function = "call_createImageData", .args = &.{ .{ .kinds = &.{.numeric} }, .{ .kinds = &.{.numeric} }, .{ .kinds = &.{.dictionary}, .optionality = .optional } } },
        .{ .function = "call_createImageData__1", .implemented = @hasDecl(CanvasImageDataImpl, "call_createImageData__1"), .args = &.{.{ .kinds = &.{(if (@hasDecl(@import("interfaces"), "ImageData")) webidl.overload_resolution.Kind{ .interface = runtime.typeId(@import("interfaces").ImageData.State) } else .other)} }} },
    } },
};
