//! Auto-generated mixin: CanvasImageData
//! Delegates to impl for actual implementation.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const CanvasImageDataImpl = @import("impls").CanvasImageData;

// Re-export types from impl
pub const impl = @import("impls").CanvasImageData;

/// Arguments for putImageData (WebIDL overloading)
pub const PutImageDataArgs = union(enum) {
    /// putImageData(imageData, dx, dy)
    ImageData_long_long: struct {
        imageData: *runtime.Instance,
        dx: runtime.JSValue,
        dy: runtime.JSValue,
    },
    /// putImageData(imageData, dx, dy, dirtyX, dirtyY, dirtyWidth, dirtyHeight)
    ImageData_long_long_long_long_long_long: struct {
        imageData: *runtime.Instance,
        dx: runtime.JSValue,
        dy: runtime.JSValue,
        dirtyX: runtime.JSValue,
        dirtyY: runtime.JSValue,
        dirtyWidth: runtime.JSValue,
        dirtyHeight: runtime.JSValue,
    },
};

pub fn call_putImageData(instance: *runtime.Instance, args: PutImageDataArgs) anyerror!void {
    return CanvasImageDataImpl.call_putImageData(instance, args);
}

/// Arguments for createImageData (WebIDL overloading)
pub const CreateImageDataArgs = union(enum) {
    /// createImageData(sw, sh, settings)
    long_long_ImageDataSettings: struct {
        sw: runtime.JSValue,
        sh: runtime.JSValue,
        settings: webidl.Opt(dictionaries.ImageDataSettings),
    },
    /// createImageData(imageData)
    ImageData: *runtime.Instance,
};

pub fn call_createImageData(instance: *runtime.Instance, args: CreateImageDataArgs) anyerror!*runtime.Instance {
    return CanvasImageDataImpl.call_createImageData(instance, args);
}

pub fn call_getImageData(instance: *runtime.Instance, sx: runtime.JSValue, sy: runtime.JSValue, sw: runtime.JSValue, sh: runtime.JSValue, settings: dictionaries.ImageDataSettings) !*runtime.Instance {
    return CanvasImageDataImpl.call_getImageData(instance, sx, sy, sw, sh, settings);
}

