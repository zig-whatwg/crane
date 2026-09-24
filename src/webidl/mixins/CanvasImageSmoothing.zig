//! Auto-generated mixin: CanvasImageSmoothing
//! Its members' delegates to the mixin's impl, which every interface that
//! includes it inherits by alias.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const CanvasImageSmoothingImpl = @import("impls").CanvasImageSmoothing;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const ImageSmoothingQuality = @import("enums").ImageSmoothingQuality;

pub const impl = @import("impls").CanvasImageSmoothing;

pub fn get_imageSmoothingEnabled(instance: *runtime.Instance) anyerror!bool {
    return try CanvasImageSmoothingImpl.get_imageSmoothingEnabled(instance);
}

pub fn set_imageSmoothingEnabled(instance: *runtime.Instance, value: bool) anyerror!void {
    try CanvasImageSmoothingImpl.set_imageSmoothingEnabled(instance, value);
}

pub fn get_imageSmoothingQuality(instance: *runtime.Instance) anyerror!ImageSmoothingQuality {
    return try CanvasImageSmoothingImpl.get_imageSmoothingQuality(instance);
}

pub fn set_imageSmoothingQuality(instance: *runtime.Instance, value: ImageSmoothingQuality) anyerror!void {
    try CanvasImageSmoothingImpl.set_imageSmoothingQuality(instance, value);
}
