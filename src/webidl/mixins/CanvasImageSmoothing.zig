//! Auto-generated mixin: CanvasImageSmoothing
//! Delegates to impl for actual implementation.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const CanvasImageSmoothingImpl = @import("impls").CanvasImageSmoothing;

// Re-export types from impl
pub const impl = @import("impls").CanvasImageSmoothing;

pub fn get_imageSmoothingEnabled(instance: *runtime.Instance) anyerror!bool {
    return CanvasImageSmoothingImpl.get_imageSmoothingEnabled(instance);
}

pub fn set_imageSmoothingEnabled(instance: *runtime.Instance, value: runtime.JSValue) !void {
    return CanvasImageSmoothingImpl.set_imageSmoothingEnabled(instance, value);
}

pub fn get_imageSmoothingQuality(instance: *runtime.Instance) anyerror!enums.ImageSmoothingQuality {
    return CanvasImageSmoothingImpl.get_imageSmoothingQuality(instance);
}

pub fn set_imageSmoothingQuality(instance: *runtime.Instance, value: enums.ImageSmoothingQuality) !void {
    return CanvasImageSmoothingImpl.set_imageSmoothingQuality(instance, value);
}

